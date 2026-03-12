class GooseStockTicker {
    [hashtable]$Config
    [hashtable]$Quotes
    [string[]]$Symbols
    [datetime]$LastUpdate
    [bool]$IsEnabled
    
    GooseStockTicker() {
        $this.Config = $this.LoadConfig()
        $this.Quotes = @{}
        $this.Symbols = @()
        $this.LastUpdate = Get-Date
        $this.IsEnabled = $false
        $this.LoadData()
    }
    
    [hashtable] LoadConfig() {
        $this.Config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $this.Config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $this.Config[$key] = [int]$value
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("StockTickerEnabled")) {
            $this.Config["StockTickerEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("StockSymbols")) {
            $this.Config["StockSymbols"] = "AAPL,GOOGL,MSFT"
        }
        if (-not $this.Config.ContainsKey("StockRefreshMinutes")) {
            $this.Config["StockRefreshMinutes"] = 5
        }
        if (-not $this.Config.ContainsKey("StockShowChange")) {
            $this.Config["StockShowChange"] = $true
        }
        if (-not $this.Config.ContainsKey("StockTickerPosition")) {
            $this.Config["StockTickerPosition"] = "right"
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_stocks.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.watchlist) {
                    $this.Symbols = @($data.watchlist)
                }
                
                if ($data.quotes) {
                    $this.Quotes = @{}
                    $data.quotes.PSObject.Properties | ForEach-Object {
                        $this.Quotes[$_.Name] = $_.Value
                    }
                }
                
                if ($data.lastUpdate) {
                    $this.LastUpdate = [datetime]::Parse($data.lastUpdate)
                }
            } catch {}
        } else {
            $this.Symbols = $this.Config["StockSymbols"] -split ","
            $this.Symbols = $this.Symbols | ForEach-Object { $_.Trim() }
        }
        
        $this.IsEnabled = $this.Config["StockTickerEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "watchlist" = $this.Symbols
            "quotes" = $this.Quotes
            "lastUpdate" = $this.LastUpdate.ToString("o")
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_stocks.json"
    }
    
    [hashtable] FetchQuote([string]$symbol) {
        $quote = @{
            "symbol" = $symbol
            "price" = 0.0
            "change" = 0.0
            "changePercent" = 0.0
            "previousClose" = 0.0
            "open" = 0.0
            "high" = 0.0
            "low" = 0.0
            "volume" = 0
            "marketCap" = 0
            "lastUpdate" = (Get-Date).ToString("o")
            "error" = $null
        }
        
        try {
            $url = "https://query1.finance.yahoo.com/v8/finance/chart/$($symbol)?interval=1d&range=1d"
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 10 -UseBasicParsing
            
            if ($response.chart.result) {
                $result = $response.chart.result[0]
                $meta = $result.meta
                $quote.price = [double]$meta.regularMarketPrice
                $quote.previousClose = [double]$meta.chartPreviousClose
                $quote.change = [double]$meta.regularMarketChange
                $quote.changePercent = [double]$meta.regularMarketChangePercent
                $quote.open = [double]$meta.regularMarketOpen
                $quote.high = [double]$meta.regularMarketDayHigh
                $quote.low = [double]$meta.regularMarketDayLow
                $quote.volume = [long]$meta.regularMarketVolume
                
                if ($meta.marketCap) {
                    $quote.marketCap = [long]$meta.marketCap
                }
            }
        } catch {
            $quote.error = $_.Exception.Message
        }
        
        return $quote
    }
    
    [hashtable] RefreshAllQuotes() {
        $results = @{}
        
        foreach ($symbol in $this.Symbols) {
            $results[$symbol] = $this.FetchQuote($symbol)
            $this.Quotes[$symbol] = $results[$symbol]
            Start-Sleep -Milliseconds 200
        }
        
        $this.LastUpdate = Get-Date
        $this.SaveData()
        
        return $results
    }
    
    [bool] AddSymbol([string]$symbol) {
        $symbol = $symbol.ToUpper().Trim()
        
        if ($this.Symbols -contains $symbol) {
            return $false
        }
        
        if ($this.Symbols.Count -ge 10) {
            return $false
        }
        
        $this.Symbols += $symbol
        $quote = $this.FetchQuote($symbol)
        $this.Quotes[$symbol] = $quote
        $this.SaveData()
        
        return $true
    }
    
    [bool] RemoveSymbol([string]$symbol) {
        $symbol = $symbol.ToUpper().Trim()
        
        if ($this.Symbols -contains $symbol) {
            $this.Symbols = $this.Symbols | Where-Object { $_ -ne $symbol }
            $this.Quotes.Remove($symbol)
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [hashtable] GetQuote([string]$symbol) {
        $symbol = $symbol.ToUpper().Trim()
        
        if ($this.Quotes.ContainsKey($symbol)) {
            return $this.Quotes[$symbol]
        }
        
        return $this.FetchQuote($symbol)
    }
    
    [hashtable[]] GetAllQuotes() {
        $result = @()
        
        foreach ($symbol in $this.Symbols) {
            if ($this.Quotes.ContainsKey($symbol)) {
                $result += $this.Quotes[$symbol]
            }
        }
        
        return $result
    }
    
    [hashtable] GetDisplayData() {
        $display = @()
        
        foreach ($symbol in $this.Symbols) {
            if ($this.Quotes.ContainsKey($symbol)) {
                $quote = $this.Quotes[$symbol]
                $isPositive = $quote.change -ge 0
                
                $display += @{
                    "Symbol" = $symbol
                    "Price" = [Math]::Round($quote.price, 2)
                    "Change" = [Math]::Round($quote.change, 2)
                    "ChangePercent" = [Math]::Round($quote.changePercent, 2)
                    "IsPositive" = $isPositive
                    "Error" = $quote.error
                }
            }
        }
        
        return @{
            "Quotes" = $display
            "LastUpdate" = $this.LastUpdate
            "IsEnabled" = $this.IsEnabled
            "SymbolCount" = $this.Symbols.Count
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["StockTickerEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["StockTickerEnabled"] = $this.IsEnabled
    }
    
    [bool] ShouldRefresh() {
        $refreshMinutes = $this.Config["StockRefreshMinutes"]
        $timeSinceUpdate = (Get-Date) - $this.LastUpdate
        
        return $timeSinceUpdate.TotalMinutes -ge $refreshMinutes
    }
    
    [hashtable] GetStockTickerState() {
        return @{
            "Enabled" = $this.IsEnabled
            "Symbols" = $this.Symbols
            "Quotes" = $this.GetAllQuotes()
            "LastUpdate" = $this.LastUpdate
            "RefreshMinutes" = $this.Config["StockRefreshMinutes"]
            "ShowChange" = $this.Config["StockShowChange"]
            "Position" = $this.Config["StockTickerPosition"]
            "ShouldRefresh" = $this.ShouldRefresh()
            "DisplayData" = $this.GetDisplayData()
        }
    }
    
    [string] GetWidgetHtml() {
        $display = $this.GetDisplayData()
        $html = "<div class='stock-ticker-widget'>"
        $html += "<div class='stock-ticker-header'>"
        $html += "<span>Stock Ticker</span>"
        if ($display.IsEnabled) {
            $html += "<button onclick='refreshStocks()'>Refresh</button>"
        }
        $html += "</div>"
        
        foreach ($quote in $display.Quotes) {
            $color = if ($quote.IsPositive) { "green" } else { "red" }
            $arrow = if ($quote.IsPositive) { "▲" } else { "▼" }
            
            $html += "<div class='stock-item'>"
            $html += "<span class='stock-symbol'>$($quote.Symbol)</span>"
            $html += "<span class='stock-price'>`$$($quote.Price)</span>"
            if ($quote.Error -eq $null) {
                $html += "<span class='stock-change $color'>$($arrow) $($quote.ChangePercent)%</span>"
            }
            $html += "</div>"
        }
        
        $html += "<div class='stock-ticker-footer'>"
        $html += "<span>Updated: $($display.LastUpdate.ToString('HH:mm'))</span>"
        $html += "</div>"
        $html += "</div>"
        
        return $html
    }
}

$gooseStockTicker = [GooseStockTicker]::new()

function Get-GooseStockTicker {
    return $gooseStockTicker
}

function Get-StockQuote {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Symbol,
        $Ticker = $gooseStockTicker
    )
    return $Ticker.GetQuote($Symbol)
}

function Add-StockSymbol {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Symbol,
        $Ticker = $gooseStockTicker
    )
    return $Ticker.AddSymbol($Symbol)
}

function Remove-StockSymbol {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Symbol,
        $Ticker = $gooseStockTicker
    )
    return $Ticker.RemoveSymbol($Symbol)
}

function Refresh-StockData {
    param($Ticker = $gooseStockTicker)
    return $Ticker.RefreshAllQuotes()
}

function Get-StockTickerState {
    param($Ticker = $gooseStockTicker)
    return $Ticker.GetStockTickerState()
}

function Get-StockDisplayData {
    param($Ticker = $gooseStockTicker)
    return $Ticker.GetDisplayData()
}

function Enable-StockTicker {
    param($Ticker = $gooseStockTicker)
    $Ticker.SetEnabled($true)
}

function Disable-StockTicker {
    param($Ticker = $gooseStockTicker)
    $Ticker.SetEnabled($false)
}

function Toggle-StockTicker {
    param($Ticker = $gooseStockTicker)
    $Ticker.Toggle()
}

Write-Host "Desktop Goose Stock Ticker Widget Initialized"
$state = Get-StockTickerState
Write-Host "Stock Ticker Enabled: $($state['Enabled'])"
Write-Host "Watchlist: $($state['Symbols'] -join ', ')"
