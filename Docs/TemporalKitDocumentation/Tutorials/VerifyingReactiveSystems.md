# Verifying Reactive Systems

This tutorial teaches you how to verify reactive systems using TemporalKit. Reactive systems are systems that continuously respond to external inputs or events, and they encompass a wide range of applications, including UI applications, servers, and IoT devices.

## Objectives

By the end of this tutorial, you will be able to:

- Model reactive systems as Kripke structures
- Express event-driven behaviors using temporal logic formulas
- Detect asynchronous processing and race conditions
- Verify responsiveness and safety properties of reactive systems

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Completion of the [Advanced LTL Formulas](./AdvancedLTLFormulas.md) tutorial

## Step 1: Understanding Reactive System Structure

First, let's understand the structure and characteristics of a typical reactive system.

```swift
import TemporalKit

// As an example of a reactive system, consider a simple UI controller
enum UserAction {
    case tap
    case swipe
    case longPress
    case none
}

enum ViewState {
    case normal
    case highlighted
    case selected
    case disabled
}

enum BackgroundTask {
    case idle
    case loading
    case processing
    case error
}

// State of a reactive UI controller
struct ReactiveUIState: Hashable, CustomStringConvertible {
    let viewState: ViewState
    let backgroundTask: BackgroundTask
    let lastUserAction: UserAction
    
    var description: String {
        return "UIState(view: \(viewState), background: \(backgroundTask), lastAction: \(lastUserAction))"
    }
}
```

## Step 2: Creating a Kripke Structure Model for Reactive Systems

Let's model a reactive system as a Kripke structure.

```swift
// Kripke structure for a reactive UI controller
struct ReactiveUIModel: KripkeStructure {
    typealias State = ReactiveUIState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Initial state
        let initialState = ReactiveUIState(
            viewState: .normal,
            backgroundTask: .idle,
            lastUserAction: .none
        )
        
        self.initialStates = [initialState]
        
        // Generate all possible state combinations
        var states = Set<State>()
        
        for viewState in [ViewState.normal, .highlighted, .selected, .disabled] {
            for backgroundTask in [BackgroundTask.idle, .loading, .processing, .error] {
                for userAction in [UserAction.none, .tap, .swipe, .longPress] {
                    states.insert(ReactiveUIState(
                        viewState: viewState,
                        backgroundTask: backgroundTask,
                        lastUserAction: userAction
                    ))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Model possible next states based on current state
        
        // 1. User action transitions
        for newAction in [UserAction.none, .tap, .swipe, .longPress] {
            // State changes due to tap
            if newAction == .tap {
                // Effect of tap depends on view state
                switch state.viewState {
                case .normal:
                    // Tap on normal state highlights it
                    nextStates.insert(ReactiveUIState(
                        viewState: .highlighted,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .highlighted:
                    // Tap on highlighted state selects it
                    nextStates.insert(ReactiveUIState(
                        viewState: .selected,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .selected:
                    // Tap on selected state returns to normal
                    nextStates.insert(ReactiveUIState(
                        viewState: .normal,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .disabled:
                    // Tap has no effect on disabled state
                    nextStates.insert(ReactiveUIState(
                        viewState: .disabled,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                }
                
                // Tap may initiate loading
                if state.backgroundTask == .idle {
                    nextStates.insert(ReactiveUIState(
                        viewState: state.viewState,
                        backgroundTask: .loading,
                        lastUserAction: .tap
                    ))
                }
            }
            
            // State changes due to swipe
            else if newAction == .swipe {
                // Swipe returns view state to normal
                nextStates.insert(ReactiveUIState(
                    viewState: .normal,
                    backgroundTask: state.backgroundTask,
                    lastUserAction: .swipe
                ))
            }
            
            // State changes due to long press
            else if newAction == .longPress {
                // Long press toggles between disabled and normal states
                if state.viewState == .disabled {
                    nextStates.insert(ReactiveUIState(
                        viewState: .normal,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .longPress
                    ))
                } else {
                    nextStates.insert(ReactiveUIState(
                        viewState: .disabled,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .longPress
                    ))
                }
            }
        }
        
        // 2. Background task transitions
        switch state.backgroundTask {
        case .idle:
            // Idle state remains unchanged
            break
            
        case .loading:
            // Loading proceeds to processing or error
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .processing,
                lastUserAction: state.lastUserAction
            ))
            
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .error,
                lastUserAction: state.lastUserAction
            ))
            
        case .processing:
            // Processing returns to idle
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .idle,
                lastUserAction: state.lastUserAction
            ))
            
        case .error:
            // Error returns to idle
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .idle,
                lastUserAction: state.lastUserAction
            ))
        }
        
        // Error state may disable UI
        if state.backgroundTask == .error {
            nextStates.insert(ReactiveUIState(
                viewState: .disabled,
                backgroundTask: state.backgroundTask,
                lastUserAction: state.lastUserAction
            ))
        }
        
        // Include current state in successors (possibility of no change)
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // View state propositions
        switch state.viewState {
        case .normal:
            trueProps.insert(isNormal.id)
        case .highlighted:
            trueProps.insert(isHighlighted.id)
        case .selected:
            trueProps.insert(isSelected.id)
        case .disabled:
            trueProps.insert(isDisabled.id)
        }
        
        // Background task propositions
        switch state.backgroundTask {
        case .idle:
            trueProps.insert(isIdle.id)
        case .loading:
            trueProps.insert(isLoading.id)
        case .processing:
            trueProps.insert(isProcessing.id)
        case .error:
            trueProps.insert(isError.id)
        }
        
        // User action propositions
        switch state.lastUserAction {
        case .none:
            trueProps.insert(noAction.id)
        case .tap:
            trueProps.insert(wasTapped.id)
        case .swipe:
            trueProps.insert(wasSwiped.id)
        case .longPress:
            trueProps.insert(wasLongPressed.id)
        }
        
        // Compound state propositions
        if state.viewState == .disabled || state.backgroundTask == .error {
            trueProps.insert(isUnresponsive.id)
        }
        
        if state.backgroundTask != .idle {
            trueProps.insert(isActive.id)
        }
        
        return trueProps
    }
}
```

## Step 3: Defining Propositions for Reactive Systems

Let's define propositions to evaluate reactive system states.

```swift
// View state propositions
let isNormal = TemporalKit.makeProposition(
    id: "isNormal",
    name: "View is in normal state",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .normal }
)

let isHighlighted = TemporalKit.makeProposition(
    id: "isHighlighted",
    name: "View is highlighted",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .highlighted }
)

let isSelected = TemporalKit.makeProposition(
    id: "isSelected",
    name: "View is selected",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .selected }
)

let isDisabled = TemporalKit.makeProposition(
    id: "isDisabled",
    name: "View is disabled",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .disabled }
)

// Background task propositions
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "No background task running",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .idle }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "Loading in background",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .loading }
)

let isProcessing = TemporalKit.makeProposition(
    id: "isProcessing",
    name: "Processing in background",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .processing }
)

let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "Error in background task",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .error }
)

// User action propositions
let noAction = TemporalKit.makeProposition(
    id: "noAction",
    name: "No user action taken",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .none }
)

let wasTapped = TemporalKit.makeProposition(
    id: "wasTapped",
    name: "View was tapped",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .tap }
)

let wasSwiped = TemporalKit.makeProposition(
    id: "wasSwiped",
    name: "View was swiped",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .swipe }
)

let wasLongPressed = TemporalKit.makeProposition(
    id: "wasLongPressed",
    name: "View was long-pressed",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .longPress }
)

// Compound state propositions
let isUnresponsive = TemporalKit.makeProposition(
    id: "isUnresponsive",
    name: "UI is unresponsive (disabled or error)",
    evaluate: { (state: ReactiveUIState) -> Bool in
        state.viewState == .disabled || state.backgroundTask == .error
    }
)

let isActive = TemporalKit.makeProposition(
    id: "isActive",
    name: "Background task is active",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask != .idle }
)
```

## Step 4: Defining LTL Properties for Reactive Systems

Now, let's define LTL formulas to verify important properties of reactive systems.

```swift
// Type aliases for readability
typealias ReactiveUIProp = ClosureTemporalProposition<ReactiveUIState, Bool>
typealias ReactiveUILTL = LTLFormula<ReactiveUIProp>

// Property 1: "Loading state is always temporary"
let loadingIsTemporary = ReactiveUILTL.globally(
    .implies(
        .atomic(isLoading),
        .eventually(
            .or(
                .atomic(isIdle),
                .atomic(isProcessing),
                .atomic(isError)
            )
        )
    )
)

// Property 2: "Tapping a disabled view has no effect on the view state"
let tappingDisabledHasNoEffect = ReactiveUILTL.globally(
    .implies(
        .and(
            .atomic(isDisabled),
            .next(.atomic(wasTapped))
        ),
        .next(.atomic(isDisabled))
    )
)

// Property 3: "UI becomes responsive again after an error"
let errorStateIsRecoverable = ReactiveUILTL.globally(
    .implies(
        .atomic(isError),
        .eventually(.atomic(isIdle))
    )
)

// Property 4: "A long press always toggles between normal and disabled state"
let longPressTogglesDisabled = ReactiveUILTL.globally(
    .implies(
        .atomic(wasLongPressed),
        .or(
            .and(
                .previous(.not(.atomic(isDisabled))),
                .atomic(isDisabled)
            ),
            .and(
                .previous(.atomic(isDisabled)),
                .not(.atomic(isDisabled))
            )
        )
    )
)

// Property 5: "A swipe always returns to normal state"
let swipeResetsState = ReactiveUILTL.globally(
    .implies(
        .atomic(wasSwiped),
        .atomic(isNormal)
    )
)

// Property 6: "After loading and processing, the system returns to idle state"
let processingCompletesSuccessfully = ReactiveUILTL.globally(
    .implies(
        .and(
            .atomic(isLoading),
            .next(.atomic(isProcessing))
        ),
        .eventually(.atomic(isIdle))
    )
)

// Property 7: "The system can always recover from unresponsive states"
let systemCanRecover = ReactiveUILTL.globally(
    .implies(
        .atomic(isUnresponsive),
        .eventually(.not(.atomic(isUnresponsive)))
    )
)
```

## Step 5: Verifying Reactive System Properties

Let's verify the properties of our reactive system model.

```swift
// Create the reactive UI model and model checker
let reactiveUIModel = ReactiveUIModel()
let modelChecker = LTLModelChecker<ReactiveUIModel>()

// Perform verification
do {
    print("Verifying reactive UI system properties...")
    
    let result1 = try modelChecker.check(formula: loadingIsTemporary, model: reactiveUIModel)
    print("Property 1 (Loading is temporary): \(result1.holds ? "holds" : "does not hold")")
    
    let result2 = try modelChecker.check(formula: tappingDisabledHasNoEffect, model: reactiveUIModel)
    print("Property 2 (Tapping disabled has no effect): \(result2.holds ? "holds" : "does not hold")")
    
    let result3 = try modelChecker.check(formula: errorStateIsRecoverable, model: reactiveUIModel)
    print("Property 3 (Error state is recoverable): \(result3.holds ? "holds" : "does not hold")")
    
    let result4 = try modelChecker.check(formula: longPressTogglesDisabled, model: reactiveUIModel)
    print("Property 4 (Long press toggles disabled): \(result4.holds ? "holds" : "does not hold")")
    
    let result5 = try modelChecker.check(formula: swipeResetsState, model: reactiveUIModel)
    print("Property 5 (Swipe resets state): \(result5.holds ? "holds" : "does not hold")")
    
    let result6 = try modelChecker.check(formula: processingCompletesSuccessfully, model: reactiveUIModel)
    print("Property 6 (Processing completes successfully): \(result6.holds ? "holds" : "does not hold")")
    
    let result7 = try modelChecker.check(formula: systemCanRecover, model: reactiveUIModel)
    print("Property 7 (System can recover): \(result7.holds ? "holds" : "does not hold")")
    
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

## Step 6: Modeling Asynchronous Behavior

Reactive systems often involve asynchronous operations. Let's extend our model to handle this aspect.

```swift
// Extended state that includes operation queue depth
struct AsyncReactiveState: Hashable, CustomStringConvertible {
    let uiState: ReactiveUIState
    let pendingOperations: Int  // Number of operations in the queue
    let operationTimeout: Bool  // Whether an operation has timed out
    
    var description: String {
        return "\(uiState), pendingOps: \(pendingOperations), timeout: \(operationTimeout)"
    }
}

// Extended model that includes asynchronous behavior
struct AsyncReactiveUIModel: KripkeStructure {
    typealias State = AsyncReactiveState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Initial state with no pending operations
        let initialState = AsyncReactiveState(
            uiState: ReactiveUIState(
                viewState: .normal,
                backgroundTask: .idle,
                lastUserAction: .none
            ),
            pendingOperations: 0,
            operationTimeout: false
        )
        
        self.initialStates = [initialState]
        
        // Generate possible states (limiting queue depth to 0-3 for simplicity)
        var states = Set<State>()
        
        let baseModel = ReactiveUIModel()
        let timeoutValues = [false, true]
        
        for uiState in baseModel.allStates {
            for pendingOps in 0...3 {  // Limit queue depth for simplicity
                for timeout in timeoutValues {
                    // Some combinations are not valid
                    if uiState.backgroundTask == .idle && pendingOps > 0 { continue }
                    if timeout && pendingOps == 0 { continue }
                    
                    states.insert(AsyncReactiveState(
                        uiState: uiState,
                        pendingOperations: pendingOps,
                        operationTimeout: timeout
                    ))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Get base UI state transitions
        let baseModel = ReactiveUIModel()
        let uiNextStates = baseModel.successors(of: state.uiState)
        
        for nextUIState in uiNextStates {
            // Handle queue additions (when an action is taken that would add to the queue)
            if state.uiState.lastUserAction == .none && nextUIState.lastUserAction != .none && 
               nextUIState.backgroundTask == .loading {
                // User action triggering a new operation - add to queue
                let nextPendingOps = min(state.pendingOperations + 1, 3)  // Cap at 3 for model simplicity
                
                nextStates.insert(AsyncReactiveState(
                    uiState: nextUIState,
                    pendingOperations: nextPendingOps,
                    operationTimeout: state.operationTimeout
                ))
            }
            
            // Handle queue processing (operations completing)
            if state.uiState.backgroundTask != .idle && nextUIState.backgroundTask == .idle &&
               state.pendingOperations > 0 {
                // Operation completed, remove from queue
                nextStates.insert(AsyncReactiveState(
                    uiState: nextUIState,
                    pendingOperations: state.pendingOperations - 1,
                    operationTimeout: false  // Reset timeout when an operation completes
                ))
            }
            
            // Handle timeout possibility
            if state.uiState.backgroundTask != .idle && state.pendingOperations > 0 {
                // Timeout can occur during active operations
                nextStates.insert(AsyncReactiveState(
                    uiState: ReactiveUIState(
                        viewState: state.uiState.viewState,
                        backgroundTask: .error,  // Timeout causes error
                        lastUserAction: state.uiState.lastUserAction
                    ),
                    pendingOperations: state.pendingOperations,
                    operationTimeout: true
                ))
            }
            
            // Regular state transition without queue changes
            nextStates.insert(AsyncReactiveState(
                uiState: nextUIState,
                pendingOperations: state.pendingOperations,
                operationTimeout: state.operationTimeout
            ))
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Include base UI propositions
        let baseModel = ReactiveUIModel()
        trueProps.formUnion(baseModel.atomicPropositionsTrue(in: state.uiState))
        
        // Add queue-related propositions
        if state.pendingOperations > 0 {
            trueProps.insert(hasPendingOperations.id)
        }
        
        if state.pendingOperations >= 3 {
            trueProps.insert(queueIsFull.id)
        }
        
        if state.operationTimeout {
            trueProps.insert(hasTimeout.id)
        }
        
        return trueProps
    }
}
```

## Step 7: Defining and Verifying Asynchronous Properties

Let's define and verify properties specific to asynchronous behavior.

```swift
// Additional propositions for asynchronous behavior
let hasPendingOperations = TemporalKit.makeProposition(
    id: "hasPendingOperations",
    name: "Has operations pending in queue",
    evaluate: { (state: AsyncReactiveState) -> Bool in state.pendingOperations > 0 }
)

let queueIsFull = TemporalKit.makeProposition(
    id: "queueIsFull",
    name: "Operation queue is full",
    evaluate: { (state: AsyncReactiveState) -> Bool in state.pendingOperations >= 3 }
)

let hasTimeout = TemporalKit.makeProposition(
    id: "hasTimeout",
    name: "An operation has timed out",
    evaluate: { (state: AsyncReactiveState) -> Bool in state.operationTimeout }
)

// Type aliases for the async model
typealias AsyncProp = ClosureTemporalProposition<AsyncReactiveState, Bool>
typealias AsyncLTL = LTLFormula<AsyncProp>

// Property 1: "Operation queue eventually empties"
let queueEventuallyEmpties = AsyncLTL.globally(
    .implies(
        .atomic(hasPendingOperations),
        .eventually(.not(.atomic(hasPendingOperations)))
    )
)

// Property 2: "Timeout leads to error state"
let timeoutCausesError = AsyncLTL.globally(
    .implies(
        .atomic(hasTimeout),
        .atomic(isError)
    )
)

// Property 3: "Queue full state is temporary"
let queueFullIsTemporary = AsyncLTL.globally(
    .implies(
        .atomic(queueIsFull),
        .eventually(.not(.atomic(queueIsFull)))
    )
)

// Property 4: "System can recover from timeout"
let systemRecoversFromTimeout = AsyncLTL.globally(
    .implies(
        .atomic(hasTimeout),
        .eventually(
            .and(
                .not(.atomic(hasTimeout)),
                .atomic(isIdle)
            )
        )
    )
)

// Verify async properties
let asyncModel = AsyncReactiveUIModel()
let asyncModelChecker = LTLModelChecker<AsyncReactiveUIModel>()

do {
    print("\nVerifying asynchronous reactive system properties...")
    
    let result1 = try asyncModelChecker.check(formula: queueEventuallyEmpties, model: asyncModel)
    print("Async Property 1 (Queue eventually empties): \(result1.holds ? "holds" : "does not hold")")
    
    let result2 = try asyncModelChecker.check(formula: timeoutCausesError, model: asyncModel)
    print("Async Property 2 (Timeout causes error): \(result2.holds ? "holds" : "does not hold")")
    
    let result3 = try asyncModelChecker.check(formula: queueFullIsTemporary, model: asyncModel)
    print("Async Property 3 (Queue full is temporary): \(result3.holds ? "holds" : "does not hold")")
    
    let result4 = try asyncModelChecker.check(formula: systemRecoversFromTimeout, model: asyncModel)
    print("Async Property 4 (System recovers from timeout): \(result4.holds ? "holds" : "does not hold")")
    
} catch {
    print("Asynchronous verification error: \(error)")
}
```

## Summary

In this tutorial, you have learned how to:

1. Model reactive systems using Kripke structures
2. Express and verify properties specific to reactive behavior
3. Handle asynchronous operations and their verification
4. Detect issues such as unresponsiveness and error states
5. Verify recovery from error conditions

Reactive systems are inherently complex due to their event-driven nature and potential for asynchronous behavior. By using formal verification with TemporalKit, you can ensure that your reactive systems meet critical responsiveness and safety properties.

## Next Steps

- Explore [Verifying UI Flows](./VerifyingUIFlows.md) to apply these concepts to interface design
- Learn about [Concurrent System Verification](./ConcurrentSystemVerification.md) for systems with multiple reactive components
- Try [Optimizing Performance](./OptimizingPerformance.md) for handling larger reactive system models
- Apply these techniques to real iOS applications, especially those with complex event-handling logic 
