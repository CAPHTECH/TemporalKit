# State Machine Verification

This tutorial teaches you how to verify state machines using TemporalKit. State machines are a core concept in many systems, and verifying their correct behavior is critical.

## Objectives

By the end of this tutorial, you will be able to:

- Properly model state machines as Kripke structures
- Express important state machine properties as LTL formulas
- Efficiently verify state machines and interpret the results
- Implement testing strategies for complex state machines

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts (see [Getting Started with TemporalKit](./BasicUsage.md) and [Simple Model Checking](./SimpleModelChecking.md))
- Basic knowledge of LTL formulas (see [Advanced LTL Formulas](./AdvancedLTLFormulas.md))

## Step 1: Modeling a State Machine

Let's model a state machine used in a real application. In this case, we'll use an audio player state machine as an example.

```swift
import TemporalKit

// Audio player states
enum AudioPlayerState: Hashable, CustomStringConvertible {
    case stopped
    case loading
    case playing
    case paused
    case buffering
    case error(code: Int)
    
    var description: String {
        switch self {
        case .stopped: return "stopped"
        case .loading: return "loading"
        case .playing: return "playing"
        case .paused: return "paused"
        case .buffering: return "buffering"
        case let .error(code): return "error(code: \(code))"
        }
    }
    
    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .stopped: hasher.combine(0)
        case .loading: hasher.combine(1)
        case .playing: hasher.combine(2)
        case .paused: hasher.combine(3)
        case .buffering: hasher.combine(4)
        case let .error(code): 
            hasher.combine(5)
            hasher.combine(code)
        }
    }
    
    // For Equatable conformance
    static func == (lhs: AudioPlayerState, rhs: AudioPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped): return true
        case (.loading, .loading): return true
        case (.playing, .playing): return true
        case (.paused, .paused): return true
        case (.buffering, .buffering): return true
        case let (.error(code1), .error(code2)): return code1 == code2
        default: return false
        }
    }
}
```

## Step 2: Implementing the State Machine as a Kripke Structure

Next, let's implement the audio player's state transitions as a Kripke structure.

```swift
// Audio player state machine
struct AudioPlayerStateMachine: KripkeStructure {
    typealias State = AudioPlayerState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [.stopped]
    
    init() {
        // Define all possible states
        var states: Set<State> = [.stopped, .loading, .playing, .paused, .buffering]
        
        // Add error states (common error codes only)
        states.insert(.error(code: 404)) // File not found
        states.insert(.error(code: 500)) // Internal error
        states.insert(.error(code: 403)) // Access denied
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        switch state {
        case .stopped:
            nextStates.insert(.loading)  // stopped → loading
            
        case .loading:
            nextStates.insert(.playing)  // loading → playing
            nextStates.insert(.error(code: 404))  // loading → error(file not found)
            nextStates.insert(.error(code: 403))  // loading → error(access denied)
            
        case .playing:
            nextStates.insert(.paused)    // playing → paused
            nextStates.insert(.buffering) // playing → buffering
            nextStates.insert(.stopped)   // playing → stopped (end of track, etc.)
            
        case .paused:
            nextStates.insert(.playing)  // paused → playing
            nextStates.insert(.stopped)  // paused → stopped
            
        case .buffering:
            nextStates.insert(.playing)  // buffering → playing
            nextStates.insert(.error(code: 500))  // buffering → error(internal error)
            
        case .error:
            nextStates.insert(.stopped)  // error → stopped (reset)
        }
        
        return nextStates
    }
    
    // Define propositions associated with states
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Basic state propositions
        switch state {
        case .stopped:
            trueProps.insert(isStopped.id)
        case .loading:
            trueProps.insert(isLoading.id)
        case .playing:
            trueProps.insert(isPlaying.id)
            trueProps.insert(isActive.id)  // playing is active
        case .paused:
            trueProps.insert(isPaused.id)
            trueProps.insert(isActive.id)  // paused is also active
        case .buffering:
            trueProps.insert(isBuffering.id)
            trueProps.insert(isActive.id)  // buffering is also active
        case .error:
            trueProps.insert(isError.id)
        }
        
        // Special state propositions
        if case .error = state {
            trueProps.insert(isInErrorState.id)
        }
        
        // Handle all error codes individually
        if case let .error(code) = state {
            switch code {
            case 404:
                trueProps.insert(isFileNotFoundError.id)
            case 500:
                trueProps.insert(isInternalError.id)
            case 403:
                trueProps.insert(isAccessDeniedError.id)
            default:
                trueProps.insert(isUnknownError.id)
            }
        }
        
        return trueProps
    }
}
```

## Step 3: Defining Propositions

Let's define propositions related to the audio player states.

```swift
// Basic state propositions
let isStopped = TemporalKit.makeProposition(
    id: "isStopped",
    name: "Player is stopped",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .stopped = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "Player is loading",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .loading = state { return true }
        return false
    }
)

let isPlaying = TemporalKit.makeProposition(
    id: "isPlaying",
    name: "Player is playing",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .playing = state { return true }
        return false
    }
)

let isPaused = TemporalKit.makeProposition(
    id: "isPaused",
    name: "Player is paused",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .paused = state { return true }
        return false
    }
)

let isBuffering = TemporalKit.makeProposition(
    id: "isBuffering",
    name: "Player is buffering",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .buffering = state { return true }
        return false
    }
)

// Error-related propositions
let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "Player is in error state",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isInErrorState = TemporalKit.makeProposition(
    id: "isInErrorState",
    name: "In some error state",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isFileNotFoundError = TemporalKit.makeProposition(
    id: "isFileNotFoundError",
    name: "File not found error",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(let code) = state, code == 404 { return true }
        return false
    }
)

let isInternalError = TemporalKit.makeProposition(
    id: "isInternalError",
    name: "Internal error",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(let code) = state, code == 500 { return true }
        return false
    }
)

let isAccessDeniedError = TemporalKit.makeProposition(
    id: "isAccessDeniedError",
    name: "Access denied error",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(let code) = state, code == 403 { return true }
        return false
    }
)

let isUnknownError = TemporalKit.makeProposition(
    id: "isUnknownError",
    name: "Unknown error",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(let code) = state, code != 404 && code != 500 && code != 403 { return true }
        return false
    }
)

// Group propositions
let isActive = TemporalKit.makeProposition(
    id: "isActive",
    name: "Player is in an active state",
    evaluate: { (state: AudioPlayerState) -> Bool in
        switch state {
        case .playing, .paused, .buffering:
            return true
        default:
            return false
        }
    }
)
```

## Step 4: Defining Important Properties to Verify

Let's define LTL formulas to verify important properties of our audio player state machine.

```swift
// Type aliases for readability
typealias AudioPlayerProp = ClosureTemporalProposition<AudioPlayerState, Bool>
typealias AudioPlayerLTL = LTLFormula<AudioPlayerProp>

// Property 1: "After loading, we eventually reach either playing or error state"
let loadingLeadsToPlayingOrError = AudioPlayerLTL.globally(
    .implies(
        .atomic(isLoading),
        .eventually(
            .or(
                .atomic(isPlaying),
                .atomic(isInErrorState)
            )
        )
    )
)

// Property 2: "We can always eventually stop the player from any state"
let canAlwaysStop = AudioPlayerLTL.globally(
    .eventually(.atomic(isStopped))
)

// Property 3: "Buffering is always temporary - it always leads back to playing or error"
let bufferingIsTemporary = AudioPlayerLTL.globally(
    .implies(
        .atomic(isBuffering),
        .eventually(
            .or(
                .atomic(isPlaying),
                .atomic(isInErrorState)
            )
        )
    )
)

// Property 4: "After any error, the next state is always stopped"
let errorLeadsToStopped = AudioPlayerLTL.globally(
    .implies(
        .atomic(isInErrorState),
        .next(.atomic(isStopped))
    )
)

// Property 5: "The player can never go directly from stopped to playing without loading first"
let noDirectStoppedToPlaying = AudioPlayerLTL.globally(
    .implies(
        .atomic(isStopped),
        .next(
            .not(.atomic(isPlaying))
        )
    )
)

// Property 6: "If playing is paused, we never enter buffering until playing resumes"
let pausingPreventsBuffering = AudioPlayerLTL.globally(
    .implies(
        .atomic(isPaused),
        .not(.atomic(isBuffering)).until(
            .or(
                .atomic(isPlaying),
                .atomic(isStopped)
            )
        )
    )
)
```

## Step 5: Verifying the State Machine

Now, let's verify our audio player state machine against these properties.

```swift
// Create the state machine and model checker
let audioPlayerStateMachine = AudioPlayerStateMachine()
let modelChecker = LTLModelChecker<AudioPlayerStateMachine>()

// Perform verification
do {
    print("Verifying audio player state machine properties...")
    
    let result1 = try modelChecker.check(formula: loadingLeadsToPlayingOrError, model: audioPlayerStateMachine)
    print("Property 1 (Loading leads to playing or error): \(result1.holds ? "holds" : "does not hold")")
    
    let result2 = try modelChecker.check(formula: canAlwaysStop, model: audioPlayerStateMachine)
    print("Property 2 (Can always stop): \(result2.holds ? "holds" : "does not hold")")
    
    let result3 = try modelChecker.check(formula: bufferingIsTemporary, model: audioPlayerStateMachine)
    print("Property 3 (Buffering is temporary): \(result3.holds ? "holds" : "does not hold")")
    
    let result4 = try modelChecker.check(formula: errorLeadsToStopped, model: audioPlayerStateMachine)
    print("Property 4 (Error leads to stopped): \(result4.holds ? "holds" : "does not hold")")
    
    let result5 = try modelChecker.check(formula: noDirectStoppedToPlaying, model: audioPlayerStateMachine)
    print("Property 5 (No direct stopped to playing): \(result5.holds ? "holds" : "does not hold")")
    
    let result6 = try modelChecker.check(formula: pausingPreventsBuffering, model: audioPlayerStateMachine)
    print("Property 6 (Pausing prevents buffering): \(result6.holds ? "holds" : "does not hold")")
    
    // Check for counterexamples
    if !result1.holds, case .fails(let counterexample) = result1 {
        print("\nCounterexample for Property 1:")
        print("Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
    
} catch {
    print("Verification error: \(error)")
}
```

## Step 6: Extending the State Machine for More Complex Behavior

Let's extend our audio player state machine to handle more complex behavior, such as tracking the current track and playlist.

```swift
// Extended audio player state with track information
struct AudioPlayerExtendedState: Hashable, CustomStringConvertible {
    let state: AudioPlayerState
    let trackIndex: Int?       // Current track index (nil if no track)
    let isLastTrack: Bool      // Whether this is the last track in the playlist
    
    var description: String {
        let trackInfo = trackIndex != nil ? "Track \(trackIndex!)" : "No track"
        let lastTrackInfo = isLastTrack ? " (Last track)" : ""
        return "\(state), \(trackInfo)\(lastTrackInfo)"
    }
}

// Extended audio player state machine
struct ExtendedAudioPlayerStateMachine: KripkeStructure {
    typealias State = AudioPlayerExtendedState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init(playlistSize: Int = 3) {
        var states = Set<State>()
        
        // Generate states for all combinations
        let baseStates: [AudioPlayerState] = [.stopped, .loading, .playing, .paused, .buffering]
        let errorStates: [AudioPlayerState] = [.error(code: 404), .error(code: 500), .error(code: 403)]
        
        // Add states with no track
        states.insert(AudioPlayerExtendedState(state: .stopped, trackIndex: nil, isLastTrack: false))
        
        // Add states with track information
        for state in baseStates + errorStates {
            for index in 0..<playlistSize {
                let isLast = index == playlistSize - 1
                states.insert(AudioPlayerExtendedState(state: state, trackIndex: index, isLastTrack: isLast))
            }
        }
        
        self.allStates = states
        self.initialStates = [AudioPlayerExtendedState(state: .stopped, trackIndex: nil, isLastTrack: false)]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        switch state.state {
        case .stopped:
            if state.trackIndex == nil {
                // If no track is selected, can load the first track
                nextStates.insert(AudioPlayerExtendedState(
                    state: .loading,
                    trackIndex: 0,
                    isLastTrack: state.isLastTrack
                ))
            } else {
                // If a track is already selected, can load the same track again
                nextStates.insert(AudioPlayerExtendedState(
                    state: .loading,
                    trackIndex: state.trackIndex,
                    isLastTrack: state.isLastTrack
                ))
                
                // Or select a different track
                if let index = state.trackIndex {
                    if index < 2 { // Not the last track
                        nextStates.insert(AudioPlayerExtendedState(
                            state: .loading,
                            trackIndex: index + 1,
                            isLastTrack: index + 1 == 2
                        ))
                    }
                    if index > 0 { // Not the first track
                        nextStates.insert(AudioPlayerExtendedState(
                            state: .loading,
                            trackIndex: index - 1,
                            isLastTrack: false
                        ))
                    }
                }
            }
            
        case .loading:
            // Loading can lead to playing or error
            nextStates.insert(AudioPlayerExtendedState(
                state: .playing,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            nextStates.insert(AudioPlayerExtendedState(
                state: .error(code: 404), // File not found
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            nextStates.insert(AudioPlayerExtendedState(
                state: .error(code: 403), // Access denied
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
        case .playing:
            // Playing can lead to paused, buffering, or stopped
            nextStates.insert(AudioPlayerExtendedState(
                state: .paused,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            nextStates.insert(AudioPlayerExtendedState(
                state: .buffering,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            // If this is the last track, can stop
            if state.isLastTrack {
                nextStates.insert(AudioPlayerExtendedState(
                    state: .stopped,
                    trackIndex: state.trackIndex,
                    isLastTrack: state.isLastTrack
                ))
            } else if let index = state.trackIndex {
                // If not the last track, can automatically move to next track
                nextStates.insert(AudioPlayerExtendedState(
                    state: .loading,
                    trackIndex: index + 1,
                    isLastTrack: index + 1 == 2
                ))
            }
            
        case .paused:
            // Paused can lead to playing or stopped
            nextStates.insert(AudioPlayerExtendedState(
                state: .playing,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            nextStates.insert(AudioPlayerExtendedState(
                state: .stopped,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
        case .buffering:
            // Buffering can lead to playing or error
            nextStates.insert(AudioPlayerExtendedState(
                state: .playing,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
            nextStates.insert(AudioPlayerExtendedState(
                state: .error(code: 500), // Internal error
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
            
        case .error:
            // Error leads back to stopped
            nextStates.insert(AudioPlayerExtendedState(
                state: .stopped,
                trackIndex: state.trackIndex,
                isLastTrack: state.isLastTrack
            ))
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Player state propositions
        switch state.state {
        case .stopped:
            trueProps.insert("isStopped")
        case .loading:
            trueProps.insert("isLoading")
        case .playing:
            trueProps.insert("isPlaying")
            trueProps.insert("isActive")
        case .paused:
            trueProps.insert("isPaused")
            trueProps.insert("isActive")
        case .buffering:
            trueProps.insert("isBuffering")
            trueProps.insert("isActive")
        case .error:
            trueProps.insert("isError")
            
            // Handle specific error codes
            if case let .error(code) = state.state {
                switch code {
                case 404:
                    trueProps.insert("isFileNotFoundError")
                case 500:
                    trueProps.insert("isInternalError")
                case 403:
                    trueProps.insert("isAccessDeniedError")
                default:
                    trueProps.insert("isUnknownError")
                }
            }
        }
        
        // Track-related propositions
        if state.trackIndex == nil {
            trueProps.insert("hasNoTrack")
        } else {
            trueProps.insert("hasTrack")
            
            if let index = state.trackIndex {
                switch index {
                case 0:
                    trueProps.insert("isFirstTrack")
                case 1:
                    trueProps.insert("isMiddleTrack")
                case 2:
                    trueProps.insert("isLastTrack")
                default:
                    break
                }
            }
        }
        
        if state.isLastTrack {
            trueProps.insert("isLastTrackInPlaylist")
        }
        
        return trueProps
    }
}
```

## Step 7: Defining and Verifying Complex Properties

Now, let's define and verify more complex properties that involve track progression.

```swift
// Create propositions for the extended state machine
let hasTrack = TemporalKit.makeProposition(
    id: "hasTrack",
    name: "Player has a track selected",
    evaluate: { (state: AudioPlayerExtendedState) -> Bool in
        return state.trackIndex != nil
    }
)

let isLastTrackInPlaylist = TemporalKit.makeProposition(
    id: "isLastTrackInPlaylist",
    name: "Current track is the last in playlist",
    evaluate: { (state: AudioPlayerExtendedState) -> Bool in
        return state.isLastTrack
    }
)

let isFirstTrack = TemporalKit.makeProposition(
    id: "isFirstTrack",
    name: "Current track is the first track",
    evaluate: { (state: AudioPlayerExtendedState) -> Bool in
        return state.trackIndex == 0
    }
)

// Type aliases for the extended model
typealias ExtendedProp = ClosureTemporalProposition<AudioPlayerExtendedState, Bool>
typealias ExtendedLTL = LTLFormula<ExtendedProp>

// Extended properties to verify
// Property 1: "Playing the last track and finishing will lead to stopped state"
let lastTrackLeadsToStopped = ExtendedLTL.globally(
    .implies(
        .and(
            .atomic(isPlaying),
            .atomic(isLastTrackInPlaylist)
        ),
        .eventually(.atomic(isStopped))
    )
)

// Property 2: "From any track, we can eventually reach the last track"
let canReachLastTrack = ExtendedLTL.globally(
    .implies(
        .atomic(hasTrack),
        .eventually(.atomic(isLastTrackInPlaylist))
    )
)

// Property 3: "A track will only be loaded once per cycle"
let trackLoadedOnce = ExtendedLTL.globally(
    .implies(
        .and(
            .atomic(isLoading),
            .atomic(isFirstTrack)
        ),
        .next(
            .not(.atomic(isLoading)).until(.atomic(isPlaying))
        )
    )
)

// Verify extended properties
let extendedStateMachine = ExtendedAudioPlayerStateMachine()
let extendedModelChecker = LTLModelChecker<ExtendedAudioPlayerStateMachine>()

do {
    print("\nVerifying extended audio player state machine properties...")
    
    let result1 = try extendedModelChecker.check(formula: lastTrackLeadsToStopped, model: extendedStateMachine)
    print("Extended Property 1 (Last track leads to stopped): \(result1.holds ? "holds" : "does not hold")")
    
    let result2 = try extendedModelChecker.check(formula: canReachLastTrack, model: extendedStateMachine)
    print("Extended Property 2 (Can reach last track): \(result2.holds ? "holds" : "does not hold")")
    
    let result3 = try extendedModelChecker.check(formula: trackLoadedOnce, model: extendedStateMachine)
    print("Extended Property 3 (Track loaded once per cycle): \(result3.holds ? "holds" : "does not hold")")
    
} catch {
    print("Extended verification error: \(error)")
}
```

## Summary

In this tutorial, you learned how to:

1. Model state machines as Kripke structures using TemporalKit
2. Define propositions to express properties of different states
3. Formulate LTL properties that capture expected behavior of state machines
4. Verify these properties using the model checker
5. Extend the state machine to handle more complex behavior

State machine verification is particularly valuable for ensuring that state-based systems behave correctly under all possible scenarios, which is difficult to achieve with traditional testing alone.

## Next Steps

- Explore [Concurrent System Verification](./ConcurrentSystemVerification.md) to model systems with multiple interacting state machines
- Learn about [Working with Propositions](./WorkingWithPropositions.md) to create more expressive properties
- Try [Integrating with Tests](./IntegratingWithTests.md) to combine state machine verification with your test suite 
