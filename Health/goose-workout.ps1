# Desktop Goose Break Workout Guide System
# Guides users through stretch exercises

class GooseBreakWorkout {
    [hashtable]$Config
    [bool]$WorkoutActive
    [int]$CurrentExerciseIndex
    [array]$Exercises
    [datetime]$WorkoutStartTime
    [int]$ExercisesCompleted
    
    GooseBreakWorkout() {
        $this.Config = $this.LoadConfig()
        $this.WorkoutActive = $false
        $this.CurrentExerciseIndex = 0
        $this.ExercisesCompleted = 0
        $this.InitializeExercises()
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
        
        if (-not $this.Config.ContainsKey("BreakWorkoutEnabled")) {
            $this.Config["BreakWorkoutEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitializeExercises() {
        $this.Exercises = @(
            @{
                "Name" = "Neck Rolls"
                "Description" = "Slowly roll your head in circles"
                "DurationSeconds" = 30
                "Instructions" = @(
                    "Drop your chin to your chest",
                    "Slowly roll your head to the right",
                    "Continue rolling back",
                    "Roll to the left and back",
                    "Repeat in the other direction"
                )
            },
            @{
                "Name" = "Shoulder Shrugs"
                "Description" = "Release tension in your shoulders"
                "DurationSeconds" = 20
                "Instructions" = @(
                    "Raise your shoulders up to your ears",
                    "Hold for 3 seconds",
                    "Release and let them drop",
                    "Repeat 10 times"
                )
            },
            @{
                "Name" = "Wrist Stretches"
                "Description" = "Give your wrists some love"
                "DurationSeconds" = 30
                "Instructions" = @(
                    "Extend your arm forward",
                    "Use other hand to gently pull fingers back",
                    "Hold for 15 seconds",
                    "Then push fingers down",
                    "Hold for 15 seconds",
                    "Switch hands"
                )
            },
            @{
                "Name" = "Eye Rest"
                "Description" = "Rest your eyes from the screen"
                "DurationSeconds" = 20
                "Instructions" = @(
                    "Close your eyes gently",
                    "Put palms over closed eyes",
                    "Don't press, just rest",
                    "Breathe deeply",
                    "Slowly open your eyes"
                )
            },
            @{
                "Name" = "Standing Stretch"
                "Description" = "Stand up and stretch your whole body"
                "DurationSeconds" = 30
                "Instructions" = @(
                    "Stand up from your chair",
                    "Reach arms above your head",
                    "Interlace fingers and stretch up",
                    "Lean gently to each side",
                    "Roll your shoulders back"
                )
            },
            @{
                "Name" = "Seated Spinal Twist"
                "Description" = "Twist your spine to release tension"
                "DurationSeconds" = 30
                "Instructions" = @(
                    "Sit up straight",
                    "Place right hand on left knee",
                    "Twist torso to the left",
                    "Hold for 15 seconds",
                    "Repeat on the other side"
                )
            },
            @{
                "Name" = "Leg Raises"
                "Description" = "Improve circulation in your legs"
                "DurationSeconds" = 30
                "Instructions" = @(
                    "While seated, extend one leg",
                    "Hold for 5 seconds",
                    "Lower slowly",
                    "Repeat with other leg",
                    "Do 10 reps each leg"
                )
            },
            @{
                "Name" = "Deep Breathing"
                "Description" = "Calm your mind and body"
                "DurationSeconds" = 45
                "Instructions" = @(
                    "Sit comfortably",
                    "Breathe in slowly for 4 counts",
                    "Hold for 4 counts",
                    "Exhale for 6 counts",
                    "Repeat 5 times"
                )
            }
        )
    }
    
    [hashtable] StartWorkout([int]$exerciseCount = 3) {
        $selected = @()
        $indices = Get-Random -InputObject (0..($this.Exercises.Count - 1)) -Count $exerciseCount
        
        foreach ($i in $indices) {
            $selected += $this.Exercises[$i]
        }
        
        $this.WorkoutActive = $true
        $this.CurrentExerciseIndex = 0
        $this.WorkoutStartTime = Get-Date
        $this.ExercisesCompleted = 0
        
        return @{
            "Success" = $true
            "Exercises" = $selected
            "TotalExercises" = $selected.Count
            "Message" = "Let's do $exerciseCount exercises together!"
        }
    }
    
    [hashtable] GetCurrentExercise() {
        if (-not $this.WorkoutActive) {
            return @{
                "Active" = $false
                "Message" = "No workout active"
            }
        }
        
        return @{
            "Active" = $true
            "Index" = $this.CurrentExerciseIndex
            "Exercise" = $this.Exercises[$this.CurrentExerciseIndex]
            "ExercisesCompleted" = $this.ExercisesCompleted
        }
    }
    
    [hashtable] CompleteExercise() {
        if (-not $this.WorkoutActive) {
            return @{
                "Success" = $false
                "Message" = "No workout active"
            }
        }
        
        $this.ExercisesCompleted++
        $nextIndex = $this.CurrentExerciseIndex + 1
        
        if ($nextIndex -ge $this.Exercises.Count) {
            return $this.EndWorkout()
        }
        
        $this.CurrentExerciseIndex = $nextIndex
        
        return @{
            "Success" = $true
            "NextExercise" = $this.Exercises[$this.CurrentExerciseIndex]
            "CompletedCount" = $this.ExercisesCompleted
        }
    }
    
    [hashtable] EndWorkout() {
        $duration = (Get-Date) - $this.WorkoutStartTime
        
        $result = @{
            "Success" = $true
            "Completed" = $true
            "ExercisesCompleted" = $this.ExercisesCompleted
            "DurationMinutes" = [Math]::Round($duration.TotalMinutes, 1)
            "Message" = "Great job! You completed $($this.ExercisesCompleted) exercises!"
        }
        
        $this.WorkoutActive = $false
        $this.CurrentExerciseIndex = 0
        
        return $result
    }
    
    [array] GetAllExercises() {
        return $this.Exercises
    }
    
    [hashtable] GetBreakWorkoutState() {
        return @{
            "Enabled" = $this.Config["BreakWorkoutEnabled"]
            "WorkoutActive" = $this.WorkoutActive
            "CurrentExerciseIndex" = $this.CurrentExerciseIndex
            "ExercisesCompleted" = $this.ExercisesCompleted
            "TotalExercises" = $this.Exercises.Count
            "CurrentExercise" = if ($this.WorkoutActive) { $this.Exercises[$this.CurrentExerciseIndex] } else { $null }
        }
    }
}

$gooseBreakWorkout = [GooseBreakWorkout]::new()

function Get-GooseBreakWorkout {
    return $gooseBreakWorkout
}

function Start-BreakWorkout {
    param(
        [int]$ExerciseCount = 3,
        $Workout = $gooseBreakWorkout
    )
    return $Workout.StartWorkout($ExerciseCount)
}

function Get-CurrentExercise {
    param($Workout = $gooseBreakWorkout)
    return $Workout.GetCurrentExercise()
}

function Complete-Exercise {
    param($Workout = $gooseBreakWorkout)
    return $Workout.CompleteExercise()
}

function Stop-BreakWorkout {
    param($Workout = $gooseBreakWorkout)
    return $Workout.EndWorkout()
}

function Get-AllExercises {
    param($Workout = $gooseBreakWorkout)
    return $Workout.GetAllExercises()
}

Write-Host "Desktop Goose Break Workout System Initialized"
$state = Get-BreakWorkoutState
Write-Host "Break Workout Enabled: $($state['Enabled'])"
Write-Host "Total Exercises: $($state['TotalExercises'])"
