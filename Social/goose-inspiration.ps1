class GooseInspiration {
    [hashtable]$Config
    [hashtable]$Quotes
    [string]$LastQuote
    [datetime]$LastQuoteTime
    [string[]]$Categories
    
    GooseInspiration() {
        $this.Config = $this.LoadConfig()
        $this.Quotes = @{}
        $this.LastQuote = ""
        $this.LastQuoteTime = Get-Date
        $this.Categories = @()
        $this.InitQuotes()
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
        
        if (-not $this.Config.ContainsKey("InspirationEnabled")) {
            $this.Config["InspirationEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("InspirationIntervalMinutes")) {
            $this.Config["InspirationIntervalMinutes"] = 60
        }
        
        return $this.Config
    }
    
    [void] InitQuotes() {
        $this.Quotes = @{
            "Motivation" = @(
                @{ Text = "The only way to do great work is to love what you do."; Author = "Steve Jobs" },
                @{ Text = "Believe you can and you're halfway there."; Author = "Theodore Roosevelt" },
                @{ Text = "Success is not final, failure is not fatal."; Author = "Winston Churchill" },
                @{ Text = "The future belongs to those who believe in their dreams."; Author = "Eleanor Roosevelt" },
                @{ Text = "It does not matter how slowly you go as long as you do not stop."; Author = "Confucius" },
                @{ Text = "Everything you've ever wanted is on the other side of fear."; Author = "George Addair" },
                @{ Text = "The best time to plant a tree was 20 years ago. The second best time is now."; Author = "Chinese Proverb" },
                @{ Text = "Your limitation—it's only your imagination."; Author = "Unknown" },
                @{ Text = "Great things never come from comfort zones."; Author = "Unknown" },
                @{ Text = "Dream it. Wish it. Do it."; Author = "Unknown" },
                @{ Text = "Success doesn't just find you. You have to go out and get it."; Author = "Unknown" },
                @{ Text = "The harder you work for something, the greater you'll feel when you achieve it."; Author = "Unknown" },
                @{ Text = "Don't stop when you're tired. Stop when you're done."; Author = "Unknown" },
                @{ Text = "Wake up with determination. Go to bed with satisfaction."; Author = "Unknown" },
                @{ Text = "Little things make big days."; Author = "Unknown" }
            )
            "Wisdom" = @(
                @{ Text = "The only true wisdom is in knowing you know nothing."; Author = "Socrates" },
                @{ Text = "In the middle of difficulty lies opportunity."; Author = "Albert Einstein" },
                @{ Text = "The journey of a thousand miles begins with one step."; Author = "Lao Tzu" },
                @{ Text = "Knowledge speaks, but wisdom listens."; Author = "Jimi Hendrix" },
                @{ Text = "The fool doth think he is wise, but the wise man knows himself to be a fool."; Author = "Shakespeare" },
                @{ Text = "Turn your wounds into wisdom."; Author = "Oprah Winfrey" },
                @{ Text = "The only thing I know is that I know nothing."; Author = "Socrates" },
                @{ Text = "Knowing yourself is the beginning of all wisdom."; Author = "Aristotle" },
                @{ Text = "By three methods we may learn wisdom: reflection, imitation, and experience."; Author = "Confucius" },
                @{ Text = "Patience is the companion of wisdom."; Author = "Saint Augustine" }
            )
            "Courage" = @(
                @{ Text = "Courage is not the absence of fear, but rather the judgment that something else is more important than fear."; Author = "Ambrose Redmoon" },
                @{ Text = "You gain strength, courage, and confidence by every experience."; Author = "Eleanor Roosevelt" },
                @{ Text = "It takes courage to grow up and become who you really are."; Author = "E.E. Cummings" },
                @{ Text = "Courage is resistance to fear, mastery of fear—not absence of fear."; Author = "Mark Twain" },
                @{ Text = "Life is either a daring adventure or nothing at all."; Author = "Helen Keller" },
                @{ Text = "Have the courage to follow your heart and intuition."; Author = "Steve Jobs" },
                @{ Text = "Courage is what it takes to stand up and speak; courage is also what it takes to sit down and listen."; Author = "Winston Churchill" },
                @{ Text = "Being deeply loved gives you strength, while loving deeply gives you courage."; Author = "Lao Tzu" }
            )
            "Perseverance" = @(
                @{ Text = "Fall seven times, stand up eight."; Author = "Japanese Proverb" },
                @{ Text = "It always seems impossible until it's done."; Author = "Nelson Mandela" },
                @{ Text = "Don't let yesterday take up too much of today."; Author = "Will Rogers" },
                @{ Text = "You learn more from failure than from success."; Author = "Unknown" },
                @{ Text = "If you get tired, learn to rest, not quit."; Author = "Unknown" },
                @{ Text = "Stars can't shine without darkness."; Author = "Unknown" },
                @{ Text = "Hard times don't create heroes. It is during the hard times when the 'hero' in us is revealed."; Author = "Bob Riley" },
                @{ Text = "Success is the sum of small efforts, repeated day in and day out."; Author = "Robert Collier" }
            )
            "Gratitude" = @(
                @{ Text = "Gratitude turns what we have into enough."; Author = "Aesop" },
                @{ Text = "Be thankful for what you have; you'll end up having more."; Author = "Oprah Winfrey" },
                @{ Text = "Gratitude is the fairest blossom which springs from the soul."; Author = "Henry Ward Beecher" },
                @{ Text = "In gratitude, there is no fear."; Author = "Zig Ziglar" },
                @{ Text = "When you are grateful, fear disappears and abundance appears."; Author = "Tony Robbins" },
                @{ Text = "Appreciation is a wonderful thing. It makes what is excellent in others belong to us as well."; Author = "Voltaire" },
                @{ Text = "Gratitude is not only the greatest of virtues, but the parent of all others."; Author = "Cicero" }
            )
            "Focus" = @(
                @{ Text = "The secret of getting ahead is getting started."; Author = "Mark Twain" },
                @{ Text = "Concentrate all your thoughts upon the work in hand."; Author = "Alexander Graham Bell" },
                @{ Text = "It is not enough to be busy. The question is: What are we busy about?"; Author = "Henry David Thoreau" },
                @{ Text = "Focus on being productive instead of busy."; Author = "Tim Ferriss" },
                @{ Text = "The successful warrior is the average man, with laser-like focus."; Author = "Bruce Lee" },
                @{ Text = "You will never reach your destination if you stop and throw stones at every dog that barks."; Author = "Winston Churchill" },
                @{ Text = "Starve your distractions, feed your focus."; Author = "Unknown" }
            )
            "Creativity" = @(
                @{ Text = "Creativity is intelligence having fun."; Author = "Albert Einstein" },
                @{ Text = "Every child is an artist. The problem is how to remain an artist once we grow up."; Author = "Pablo Picasso" },
                @{ Text = "Creativity takes courage."; Author = "Henri Matisse" },
                @{ Text = "You can't use up creativity. The more you use, the more you have."; Author = "Maya Angelou" },
                @{ Text = "Imagination is the beginning of creation."; Author = "George Bernard Shaw" },
                @{ Text = "The chief enemy of creativity is good sense."; Author = "Pablo Picasso" }
            )
            "Kindness" = @(
                @{ Text = "No act of kindness, no matter how small, is ever wasted."; Author = "Aesop" },
                @{ Text = "Kindness is a language that the deaf can hear and the blind can see."; Author = "Mark Twain" },
                @{ Text = "Three things in human life are important: the first is to be kind, the second is to be kind, and the third is to be kind."; Author = "Henry James" },
                @{ Text = "Kindness is the golden chain by which society is bound together."; Author = "Johann Heinrich Pestalozzi" },
                @{ Text = "A little bit of kindness goes a long way."; Author = "Unknown" },
                @{ Text = "Be kind whenever possible. It is always possible."; Author = "Dalai Lama" }
            )
        }
        
        $this.Categories = @($this.Quotes.Keys)
    }
    
    [hashtable] GetRandomQuote([string]$category = "") {
        $selectedCategory = $category
        
        if ($selectedCategory -eq "" -or $selectedCategory -eq "Random") {
            $selectedCategory = $this.Categories | Get-Random
        }
        
        if (-not $this.Quotes.ContainsKey($selectedCategory)) {
            $selectedCategory = $this.Categories | Get-Random
        }
        
        $quotes = $this.Quotes[$selectedCategory]
        $quote = $quotes | Get-Random
        
        $this.LastQuote = $quote.Text
        $this.LastQuoteTime = Get-Date
        
        return @{
            "Text" = $quote.Text
            "Author" = $quote.Author
            "Category" = $selectedCategory
            "Timestamp" = $this.LastQuoteTime
        }
    }
    
    [hashtable] GetQuoteOfTheDay() {
        $dayOfYear = (Get-Date).DayOfYear
        $categoryIndex = $dayOfYear % $this.Categories.Count
        $category = $this.Categories[$categoryIndex]
        
        $quotes = $this.Quotes[$category]
        $quoteIndex = $dayOfYear % $quotes.Count
        
        return @{
            "Text" = $quotes[$quoteIndex].Text
            "Author" = $quotes[$quoteIndex].Author
            "Category" = $category
            "IsQuoteOfTheDay" = $true
        }
    }
    
    [bool] ShouldShowQuote() {
        $interval = $this.Config["InspirationIntervalMinutes"]
        $minutesSince = ((Get-Date) - $this.LastQuoteTime).TotalMinutes
        
        return $minutesSince -ge $interval
    }
    
    [string[]] GetCategories() {
        return $this.Categories
    }
    
    [hashtable[]] GetQuotesByCategory([string]$category) {
        if ($this.Quotes.ContainsKey($category)) {
            return $this.Quotes[$category]
        }
        
        return @()
    }
    
    [hashtable] GetInspirationState() {
        return @{
            "Enabled" = $this.Config["InspirationEnabled"]
            "Categories" = $this.Categories
            "QuoteOfTheDay" = $this.GetQuoteOfTheDay()
            "RandomQuote" = $this.GetRandomQuote()
            "ShouldShowQuote" = $this.ShouldShowQuote()
            "LastQuote" = @{
                "Text" = $this.LastQuote
                "Time" = $this.LastQuoteTime
            }
        }
    }
}

$gooseInspiration = [GooseInspiration]::new()

function Get-GooseInspiration {
    return $gooseInspiration
}

function Get-RandomQuote {
    param(
        [string]$Category = "",
        $Inspiration = $gooseInspiration
    )
    return $Inspiration.GetRandomQuote($Category)
}

function Get-QuotesByCategory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Category,
        $Inspiration = $gooseInspiration
    )
    return $Inspiration.GetQuotesByCategory($Category)
}

function Get-InspirationStatus {
    param($Inspiration = $gooseInspiration)
    return $Inspiration.GetInspirationState()
}

Write-Host "Desktop Goose Inspiration System Initialized"
$state = Get-InspirationStatus
Write-Host "Inspiration Enabled: $($state['Enabled'])"
Write-Host "Categories: $($state['Categories'] -join ', ')"
