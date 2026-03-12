# Desktop Goose Daily Quote System
# Display motivational quotes

class GooseDailyQuote {
    [hashtable]$Config
    [array]$Quotes
    [string]$LastQuote
    [datetime]$LastQuoteDate
    
    GooseDailyQuote() {
        $this.Config = $this.LoadConfig()
        $this.LastQuote = ""
        $this.LastQuoteDate = (Get-Date).AddDays(-1)
        $this.InitializeQuotes()
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
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("DailyQuoteEnabled")) {
            $this.Config["DailyQuoteEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitializeQuotes() {
        $this.Quotes = @(
            @{ "Quote" = "The only way to do great work is to love what you do."; "Author" = "Steve Jobs" },
            @{ "Quote" = "Innovation distinguishes between a leader and a follower."; "Author" = "Steve Jobs" },
            @{ "Quote" = "Stay hungry, stay foolish."; "Author" = "Steve Jobs" },
            @{ "Quote" = "The future belongs to those who believe in the beauty of their dreams."; "Author" = "Eleanor Roosevelt" },
            @{ "Quote" = "It is during our darkest moments that we must focus to see the light."; "Author" = "Aristotle" },
            @{ "Quote" = "The best time to plant a tree was 20 years ago. The second best time is now."; "Author" = "Chinese Proverb" },
            @{ "Quote" = "Your time is limited, don't waste it living someone else's life."; "Author" = "Steve Jobs" },
            @{ "Quote" = "The only impossible journey is the one you never begin."; "Author" = "Tony Robbins" },
            @{ "Quote" = "Success is not final, failure is not fatal: it is the courage to continue that counts."; "Author" = "Winston Churchill" },
            @{ "Quote" = "Believe you can and you're halfway there."; "Author" = "Theodore Roosevelt" },
            @{ "Quote" = "The greatest glory in living lies not in never falling, but in rising every time we fall."; "Author" = "Nelson Mandela" },
            @{ "Quote" = "Life is what happens when you're busy making other plans."; "Author" = "John Lennon" },
            @{ "Quote" = "You must be the change you wish to see in the world."; "Author" = "Mahatma Gandhi" },
            @{ "Quote" = "The way to get started is to quit talking and begin doing."; "Author" = "Walt Disney" },
            @{ "Quote" = "Don't let yesterday take up too much of today."; "Author" = "Will Rogers" },
            @{ "Quote" = "You learn more from failure than from success. Don't let it stop you."; "Author" = "Unknown" },
            @{ "Quote" = "It's not whether you get knocked down, it's whether you get up."; "Author" = "Vince Lombardi" },
            @{ "Quote" = "People who are crazy enough to think they can change the world, are the ones who do."; "Author" = "Rob Siltanen" },
            @{ "Quote" = "Whether you think you can or you think you can't, you're right."; "Author" = "Henry Ford" },
            @{ "Quote" = "The only limit to our realization of tomorrow is our doubts of today."; "Author" = "Franklin D. Roosevelt" },
            @{ "Quote" = "Do what you can, with what you have, where you are."; "Author" = "Theodore Roosevelt" },
            @{ "Quote" = "Everything you've ever wanted is on the other side of fear."; "Author" = "George Addair" },
            @{ "Quote" = "Success usually comes to those who are too busy to be looking for it."; "Author" = "Henry David Thoreau" },
            @{ "Quote" = "Don't be afraid to give up the good to go for the great."; "Author" = "John D. Rockefeller" },
            @{ "Quote" = "I find that the harder I work, the more luck I seem to have."; "Author" = "Thomas Jefferson" }
        )
    }
    
    [hashtable] GetDailyQuote() {
        $today = (Get-Date).Date
        
        if ($this.LastQuoteDate.Date -eq $today -and $this.LastQuote -ne "") {
            return @{
                "Quote" = $this.LastQuote.Quote
                "Author" = $this.LastQuote.Author
                "IsNew" = $false
                "Date" = $today.ToString("yyyy-MM-dd")
            }
        }
        
        $dayOfYear = (Get-Date).DayOfYear
        $quoteIndex = $dayOfYear % $this.Quotes.Count
        
        $this.LastQuote = $this.Quotes[$quoteIndex]
        $this.LastQuoteDate = Get-Date
        
        return @{
            "Quote" = $this.LastQuote.Quote
            "Author" = $this.LastQuote.Author
            "IsNew" = $true
            "Date" = $today.ToString("yyyy-MM-dd")
        }
    }
    
    [hashtable] GetRandomQuote() {
        $quote = Get-Random -InputObject $this.Quotes
        
        return @{
            "Quote" = $quote.Quote
            "Author" = $quote.Author
            "IsRandom" = $true
        }
    }
    
    [void] AddQuote([string]$quote, [string]$author) {
        $this.Quotes += @{
            "Quote" = $quote
            "Author" = $author
        }
    }
    
    [hashtable] GetDailyQuoteState() {
        return @{
            "Enabled" = $this.Config["DailyQuoteEnabled"]
            "QuoteCount" = $this.Quotes.Count
            "LastQuoteDate" = $this.LastQuoteDate.ToString("yyyy-MM-dd")
            "TodayQuote" = $this.GetDailyQuote()
        }
    }
}

$gooseDailyQuote = [GooseDailyQuote]::new()

function Get-GooseDailyQuote {
    return $gooseDailyQuote
}

function Get-DailyQuote {
    param($Quote = $gooseDailyQuote)
    return $Quote.GetDailyQuote()
}

function Get-RandomQuote {
    param($Quote = $gooseDailyQuote)
    return $Quote.GetRandomQuote()
}

function Get-DailyQuoteState {
    param($Quote = $gooseDailyQuote)
    return $Quote.GetDailyQuoteState()
}

Write-Host "Desktop Goose Daily Quote System Initialized"
$state = Get-DailyQuoteState
Write-Host "Daily Quote Enabled: $($state['Enabled'])"
Write-Host "Quote of the day: $($state['TodayQuote']['Quote'].Substring(0, [Math]::Min(50, $state['TodayQuote']['Quote'].Length)))..."
