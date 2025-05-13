# TemporalKit Use Cases

TemporalKit can be utilized in various iOS application development scenarios. This document introduces common use cases and their implementation examples.

## Table of Contents

- [Application State Management](#application-state-management)
- [User Flow Verification](#user-flow-verification)
- [SwiftUI State Machine Verification](#swiftui-state-machine-verification)
- [Network Layer Reliability](#network-layer-reliability)
- [Concurrent and Asynchronous Operations](#concurrent-and-asynchronous-operations)
- [Animation and Transition Sequences](#animation-and-transition-sequences)
- [Error Handling Paths](#error-handling-paths)
- [Security Properties](#security-properties)

## Application State Management

iOS applications often have complex state transitions, and it's important to verify that all state transitions are valid and that the system doesn't fall into an abnormal state.

### Example: Authentication State Verification

```swift
// Define application authentication states
enum AuthState: Hashable {
    case loggedOut
    case loggingIn
    case loggedIn
    case authError
    case refreshingToken
}

// Model the authentication subsystem as a Kripke structure
struct AuthStateModel: KripkeStructure {
    typealias State = AuthState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.loggedOut]
    let allStates: Set<State> = [.loggedOut, .loggingIn, .loggedIn, .authError, .refreshingToken]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .loggedOut:
            return [.loggingIn]
        case .loggingIn:
            return [.loggedIn, .authError]
        case .loggedIn:
            return [.loggedIn, .refreshingToken, .loggedOut]
        case .authError:
            return [.loggedOut, .loggingIn]
        case .refreshingToken:
            return [.loggedIn, .loggedOut]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .loggedOut:
            return ["isLoggedOut"]
        case .loggingIn:
            return ["isTransitioning"]
        case .loggedIn:
            return ["isAuthenticated", "canAccessContent"]
        case .authError:
            return ["hasError"]
        case .refreshingToken:
            return ["isAuthenticated", "isTransitioning"]
        }
    }
}

// Properties to verify:
// 1. Authentication errors should always lead back to login screen or logged out state
// 2. Transitional states should always eventually reach a stable state
// 3. Users should always be able to log out from an authenticated state
```

## User Flow Verification

Verify complex user flows such as onboarding, registration, and checkout processes.

### Example: Onboarding Flow Verification

```swift
// Define onboarding states
enum OnboardingState: Hashable {
    case welcome
    case permissions
    case accountCreation
    case profileSetup
    case tutorial
    case complete
    case skipped
}

// Implement onboarding model
struct OnboardingModel: KripkeStructure {
    typealias State = OnboardingState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.welcome]
    let allStates: Set<State> = [.welcome, .permissions, .accountCreation, 
                                .profileSetup, .tutorial, .complete, .skipped]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .welcome:
            return [.permissions, .skipped]
        case .permissions:
            return [.accountCreation, .skipped]
        case .accountCreation:
            return [.profileSetup, .skipped]
        case .profileSetup:
            return [.tutorial, .complete, .skipped]
        case .tutorial:
            return [.complete]
        case .complete, .skipped:
            return [] // Terminal states
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .welcome:
            return ["isWelcome"]
        case .permissions:
            return ["isPermissions"]
        case .accountCreation:
            return ["isCreatingAccount"]
        case .profileSetup:
            return ["isSettingUpProfile"]
        case .tutorial:
            return ["isTutorial"]
        case .complete:
            return ["isComplete"]
        case .skipped:
            return ["isSkipped"]
        }
    }
}

// Properties to verify:
// 1. Users can always skip the flow
// 2. To reach the completed state, users must go through the permissions screen
// 3. From the skipped state, there is no transition to other states
```

## SwiftUI State Machine Verification

SwiftUI Views can be thought of as state machines where the display changes based on state. We can verify that these state transitions are correct.

### Example: Data Loading State Verification

```swift
// Define SwiftUI view states
enum ViewState: Hashable {
    case initial
    case loading
    case loaded(Data)
    case empty
    case error(Error)
}

// Wrapper to make Error Hashable
struct ViewError: Hashable, Error {
    let message: String
    
    static func == (lhs: ViewError, rhs: ViewError) -> Bool {
        lhs.message == rhs.message
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(message)
    }
}

// Wrapper to make Data Hashable
struct ViewData: Hashable {
    let id: UUID
    let content: String
    
    static func == (lhs: ViewData, rhs: ViewData) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Implement view state model
struct ViewStateModel: KripkeStructure {
    typealias State = ViewState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.initial]
    let allStates: Set<State>
    
    init() {
        var states: Set<State> = [.initial, .loading, .empty]
        
        // Add sample data and error
        let sampleData = ViewData(id: UUID(), content: "Sample")
        let sampleError = ViewError(message: "Network error")
        
        states.insert(.loaded(sampleData))
        states.insert(.error(sampleError))
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        let sampleData = ViewData(id: UUID(), content: "Sample")
        let sampleError = ViewError(message: "Network error")
        
        switch state {
        case .initial:
            return [.loading]
        case .loading:
            return [.loaded(sampleData), .empty, .error(sampleError)]
        case .loaded:
            return [.loading, .initial]
        case .empty:
            return [.loading, .initial]
        case .error:
            return [.loading, .initial]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .initial:
            return ["isInitial"]
        case .loading:
            return ["isLoading"]
        case .loaded:
            return ["isLoaded", "hasData"]
        case .empty:
            return ["isLoaded", "isEmpty"]
        case .error:
            return ["hasError"]
        }
    }
}

// Properties to verify:
// 1. Loading state always terminates
// 2. From error state, it's always possible to retry
// 3. There is always a path back to the initial state
```

## Network Layer Reliability

Verify the reliability of network request handling, including retries, caching, and error handling.

### Example: Network Request State Verification

```swift
// Define network request states
enum NetworkRequestState: Hashable {
    case idle
    case preparing
    case requesting
    case receivingResponse
    case processingResponse
    case completed(Data)
    case failed(Error)
    case retrying(Int) // Attempt count
}

// Network request model
struct NetworkRequestModel: KripkeStructure {
    typealias State = NetworkRequestState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.idle]
    let allStates: Set<State>
    let maxRetries = 3
    
    init() {
        var states: Set<State> = [.idle, .preparing, .requesting, .receivingResponse, .processingResponse]
        
        // Sample data and error
        let sampleData = "SampleData".data(using: .utf8)!
        let sampleError = NSError(domain: "NetworkError", code: 1, userInfo: nil)
        
        states.insert(.completed(sampleData))
        states.insert(.failed(sampleError))
        
        // Retry states
        for i in 1...maxRetries {
            states.insert(.retrying(i))
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        let sampleData = "SampleData".data(using: .utf8)!
        let sampleError = NSError(domain: "NetworkError", code: 1, userInfo: nil)
        
        switch state {
        case .idle:
            nextStates.insert(.preparing)
            
        case .preparing:
            nextStates.insert(.requesting)
            
        case .requesting:
            nextStates.insert(.receivingResponse)
            nextStates.insert(.failed(sampleError))
            
        case .receivingResponse:
            nextStates.insert(.processingResponse)
            nextStates.insert(.failed(sampleError))
            
        case .processingResponse:
            nextStates.insert(.completed(sampleData))
            nextStates.insert(.failed(sampleError))
            
        case .completed:
            nextStates.insert(.idle)
            
        case .failed:
            nextStates.insert(.idle)
            nextStates.insert(.retrying(1))
            
        case .retrying(let attempt):
            if attempt < maxRetries {
                nextStates.insert(.retrying(attempt + 1))
            }
            nextStates.insert(.requesting)
            nextStates.insert(.idle)
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .idle:
            props.insert("isIdle")
            
        case .preparing:
            props.insert("isActive")
            props.insert("isPreparing")
            
        case .requesting:
            props.insert("isActive")
            props.insert("isRequesting")
            
        case .receivingResponse:
            props.insert("isActive")
            props.insert("isReceivingResponse")
            
        case .processingResponse:
            props.insert("isActive")
            props.insert("isProcessingResponse")
            
        case .completed:
            props.insert("isCompleted")
            props.insert("hasData")
            
        case .failed:
            props.insert("isFailed")
            props.insert("hasError")
            
        case .retrying(let attempt):
            props.insert("isRetrying")
            props.insert("isActive")
            props.insert("retryAttempt\(attempt)")
        }
        
        return props
    }
}

// Properties to verify:
// 1. The system never gets stuck in an active state
// 2. After a failure, either retry or return to idle
// 3. Maximum retry count is never exceeded
```

## Concurrent and Asynchronous Operations

Verify the correctness of concurrent and asynchronous operations, ensuring that no race conditions or deadlocks occur.

### Example: Task Execution System

```swift
// Define task states
enum TaskState: Hashable {
    case waiting
    case ready
    case executing
    case blocked
    case completed
    case failed
}

// Task relationships
struct TaskDependency: Hashable {
    let taskId: String
    let dependencyId: String
}

// Task system model
struct TaskSystemModel: KripkeStructure {
    typealias State = [String: TaskState]
    typealias AtomicPropositionIdentifier = String
    
    let taskIds: [String]
    let dependencies: [TaskDependency]
    
    let initialStates: Set<State>
    let allStates: Set<State>
    
    init(taskIds: [String], dependencies: [TaskDependency]) {
        self.taskIds = taskIds
        self.dependencies = dependencies
        
        // Initial state: all tasks are waiting
        var initialState = [String: TaskState]()
        for id in taskIds {
            initialState[id] = .waiting
        }
        self.initialStates = [initialState]
        
        // Generate all possible states
        // Note: In a real implementation, you would generate these algorithmically
        // This is simplified for the example
        self.allStates = Self.generateAllStates(taskIds: taskIds)
    }
    
    private static func generateAllStates(taskIds: [String]) -> Set<State> {
        // This would generate all possible combinations of task states
        // Simplified implementation for example purposes
        var result: Set<State> = []
        
        // Add a few sample states
        var state1 = [String: TaskState]()
        var state2 = [String: TaskState]()
        var state3 = [String: TaskState]()
        
        for id in taskIds {
            state1[id] = .waiting
            state2[id] = .executing
            state3[id] = .completed
        }
        
        result.insert(state1)
        result.insert(state2)
        result.insert(state3)
        
        return result
    }
    
    func successors(of state: State) -> Set<State> {
        var result = Set<State>()
        
        // For each task, determine what state transitions are valid
        for taskId in taskIds {
            guard let currentState = state[taskId] else { continue }
            
            var newState = state
            
            switch currentState {
            case .waiting:
                // Can move to ready if all dependencies are completed
                let canBeReady = dependencies
                    .filter { $0.taskId == taskId }
                    .allSatisfy { state[$0.dependencyId] == .completed }
                
                if canBeReady {
                    newState[taskId] = .ready
                    result.insert(newState)
                }
                
            case .ready:
                // Can start executing
                newState[taskId] = .executing
                result.insert(newState)
                
            case .executing:
                // Can complete, fail, or get blocked
                newState[taskId] = .completed
                result.insert(newState)
                
                newState[taskId] = .failed
                result.insert(newState)
                
                newState[taskId] = .blocked
                result.insert(newState)
                
            case .blocked:
                // Can resume execution or fail
                newState[taskId] = .executing
                result.insert(newState)
                
                newState[taskId] = .failed
                result.insert(newState)
                
            case .completed, .failed:
                // Terminal states
                break
            }
        }
        
        return result
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        // Add propositions for each task state
        for (taskId, taskState) in state {
            switch taskState {
            case .waiting:
                props.insert("task_\(taskId)_waiting")
            case .ready:
                props.insert("task_\(taskId)_ready")
            case .executing:
                props.insert("task_\(taskId)_executing")
            case .blocked:
                props.insert("task_\(taskId)_blocked")
            case .completed:
                props.insert("task_\(taskId)_completed")
            case .failed:
                props.insert("task_\(taskId)_failed")
            }
        }
        
        // Add proposition for all tasks completed
        if state.allSatisfy({ $0.value == .completed }) {
            props.insert("allTasksCompleted")
        }
        
        // Add proposition for any task failed
        if state.contains(where: { $0.value == .failed }) {
            props.insert("someTaskFailed")
        }
        
        return props
    }
}

// Properties to verify:
// 1. No deadlocks (all tasks eventually complete or fail)
// 2. Tasks don't start executing before dependencies complete
// 3. When a task fails, dependent tasks don't execute
```

## Animation and Transition Sequences

Verify the correctness of complex animation and transition sequences, ensuring that animations occur in the correct order and don't get stuck.

### Example: Animation Sequence Verification

```swift
// Define animation states
enum AnimationState: Hashable {
    case idle
    case fadeOutInitial
    case movingContent
    case scalingEffect
    case fadeInNew
    case completed
    case interrupted
}

// Animation sequence model
struct AnimationSequenceModel: KripkeStructure {
    typealias State = AnimationState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.idle]
    let allStates: Set<State> = [.idle, .fadeOutInitial, .movingContent, 
                               .scalingEffect, .fadeInNew, .completed, .interrupted]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .idle:
            return [.fadeOutInitial, .idle]
        case .fadeOutInitial:
            return [.movingContent, .interrupted]
        case .movingContent:
            return [.scalingEffect, .interrupted]
        case .scalingEffect:
            return [.fadeInNew, .interrupted]
        case .fadeInNew:
            return [.completed, .interrupted]
        case .completed:
            return [.idle]
        case .interrupted:
            return [.idle]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .idle:
            return ["isIdle"]
        case .fadeOutInitial:
            return ["isAnimating", "isFadingOut"]
        case .movingContent:
            return ["isAnimating", "isMoving"]
        case .scalingEffect:
            return ["isAnimating", "isScaling"]
        case .fadeInNew:
            return ["isAnimating", "isFadingIn"]
        case .completed:
            return ["isCompleted"]
        case .interrupted:
            return ["isInterrupted"]
        }
    }
}

// Properties to verify:
// 1. Animations always complete or get interrupted
// 2. Completed animations always return to idle
// 3. Animation steps occur in the correct sequence
```

## Error Handling Paths

Verify that all error handling paths are correct and that the system recovers appropriately from errors.

### Example: Error Recovery Model

```swift
// Define application error states
enum ErrorState: Hashable {
    case noError
    case minorError
    case majorError
    case criticalError
    case recovering
    case retrying
}

// Error handling model
struct ErrorHandlingModel: KripkeStructure {
    typealias State = ErrorState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.noError]
    let allStates: Set<State> = [.noError, .minorError, .majorError, 
                               .criticalError, .recovering, .retrying]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .noError:
            return [.noError, .minorError, .majorError, .criticalError]
        case .minorError:
            return [.retrying, .noError]
        case .majorError:
            return [.recovering, .criticalError]
        case .criticalError:
            return [.recovering]
        case .recovering:
            return [.noError, .minorError]
        case .retrying:
            return [.noError, .minorError, .majorError]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .noError:
            return ["isStable", "isOperational"]
        case .minorError:
            return ["hasError", "isRecoverable", "isOperational"]
        case .majorError:
            return ["hasError", "isRecoverable", "needsRecovery"]
        case .criticalError:
            return ["hasError", "isCritical", "needsRecovery"]
        case .recovering:
            return ["isRecovering", "inProgress"]
        case .retrying:
            return ["isRetrying", "inProgress", "isOperational"]
        }
    }
}

// Properties to verify:
// 1. System always recovers from errors
// 2. Critical errors are always properly handled
// 3. System doesn't get stuck in error recovery loops
```

## Security Properties

Verify security-related properties, such as authorization, permissions, and data access controls.

### Example: Authorization Model

```swift
// Define authorization states
enum AuthorizationState: Hashable {
    case unauthenticated
    case authenticated
    case authorized(Set<Permission>)
    case permissionDenied
}

// Permission types
enum Permission: String, Hashable {
    case read
    case write
    case admin
}

// Authorization model
struct AuthorizationModel: KripkeStructure {
    typealias State = AuthorizationState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.unauthenticated]
    let allStates: Set<State>
    
    init() {
        var states: Set<State> = [.unauthenticated, .authenticated, .permissionDenied]
        
        // Add states with different permission combinations
        states.insert(.authorized([.read]))
        states.insert(.authorized([.read, .write]))
        states.insert(.authorized([.read, .write, .admin]))
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .unauthenticated:
            return [.unauthenticated, .authenticated, .permissionDenied]
        case .authenticated:
            return [.authenticated, .authorized([.read]), .permissionDenied, .unauthenticated]
        case .authorized(let permissions):
            var nextStates: Set<State> = [.unauthenticated, .permissionDenied]
            
            // Can upgrade or downgrade permissions
            if !permissions.contains(.write) {
                var upgradedPermissions = permissions
                upgradedPermissions.insert(.write)
                nextStates.insert(.authorized(upgradedPermissions))
            } else if !permissions.contains(.admin) {
                var upgradedPermissions = permissions
                upgradedPermissions.insert(.admin)
                nextStates.insert(.authorized(upgradedPermissions))
            }
            
            // Can maintain current permissions
            nextStates.insert(.authorized(permissions))
            
            return nextStates
        case .permissionDenied:
            return [.unauthenticated, .authenticated]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .unauthenticated:
            props.insert("isUnauthenticated")
        case .authenticated:
            props.insert("isAuthenticated")
            props.insert("noPermissions")
        case .authorized(let permissions):
            props.insert("isAuthenticated")
            props.insert("isAuthorized")
            
            for permission in permissions {
                props.insert("has\(permission.rawValue.capitalized)Permission")
            }
            
            if permissions.contains(.admin) {
                props.insert("isAdmin")
            }
        case .permissionDenied:
            props.insert("isAuthenticated")
            props.insert("isPermissionDenied")
        }
        
        return props
    }
}

// Properties to verify:
// 1. Admin permission requires authentication
// 2. After permission denial, can only authenticate again or log out
// 3. Higher permissions include all lower permissions
```

By leveraging TemporalKit for these use cases, you can ensure the correctness of your application's critical behaviors and transitions. 
