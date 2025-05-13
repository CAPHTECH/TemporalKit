# Modeling State Machines

This tutorial explains how to model state machines using TemporalKit and represent them as Kripke structures for formal verification.

## Prerequisites

Before starting this tutorial, make sure you have:

- Completed the [Basic Usage](./BasicUsage.md) tutorial
- Understood the concept of Kripke structures from the [Core Concepts](../CoreConcepts.md) document
- Imported TemporalKit in your project

## Understanding State Machines

State machines are a fundamental modeling concept in computer science. They consist of:

- A set of states
- Transitions between states
- Actions that occur on transitions
- Initial states
- (Possibly) final states

In TemporalKit, we represent state machines as Kripke structures, which are mathematical models used for formal verification.

## 1. Defining States

First, define the states of your system. Usually, an enum is a good choice for simple state machines:

```swift
import TemporalKit

// Define states for a simple coffee machine
enum CoffeeMachineState: Hashable {
    case idle
    case brewing
    case dispensing
    case waterEmpty
    case maintainRequired
    case error
}
```

For more complex states with associated data, you can use structs:

```swift
// A more detailed state definition
struct DetailedCoffeeMachineState: Hashable {
    enum Mode {
        case idle
        case brewing
        case dispensing
        case maintenance
        case error
    }
    
    let mode: Mode
    let waterLevel: Int // 0-100 percent
    let beansLevel: Int // 0-100 percent
    let cupCount: Int
    let errorCode: Int? // nil if no error
    
    // For large state spaces, consider implementing custom Hashable
    // to abstract away details that aren't relevant for verification
}
```

## 2. Creating a Kripke Structure

To perform verification, we need to represent our state machine as a `KripkeStructure`. This protocol requires defining:

- All possible states
- Initial states
- Successor states for each state
- Atomic propositions true in each state

Here's how to implement a basic coffee machine as a Kripke structure:

```swift
struct CoffeeMachineModel: KripkeStructure {
    typealias State = CoffeeMachineState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<CoffeeMachineState> = [
        .idle, .brewing, .dispensing, .waterEmpty, .maintainRequired, .error
    ]
    
    let initialStates: Set<CoffeeMachineState> = [.idle]
    
    func successors(of state: CoffeeMachineState) -> Set<CoffeeMachineState> {
        switch state {
        case .idle:
            return [.brewing, .maintainRequired, .waterEmpty]
        case .brewing:
            return [.dispensing, .error]
        case .dispensing:
            return [.idle]
        case .waterEmpty:
            return [.idle] // After refilling water
        case .maintainRequired:
            return [.idle] // After maintenance
        case .error:
            return [.idle, .error] // After reset or if error persists
        }
    }
    
    func atomicPropositionsTrue(in state: CoffeeMachineState) -> Set<String> {
        switch state {
        case .idle:
            return ["isIdle", "isReady"]
        case .brewing:
            return ["isBrewing", "isWorking"]
        case .dispensing:
            return ["isDispensing", "isWorking"]
        case .waterEmpty:
            return ["isWaterEmpty", "needsAttention"]
        case .maintainRequired:
            return ["needsMaintenance", "needsAttention"]
        case .error:
            return ["isError", "needsAttention"]
        }
    }
}
```

## 3. Handling Large State Spaces

For more complex systems with large state spaces, we can generate states and transitions programmatically:

```swift
struct DetailedCoffeeMachineModel: KripkeStructure {
    typealias State = DetailedCoffeeMachineState
    typealias AtomicPropositionIdentifier = String
    
    // Generate all possible states systematically
    var allStates: Set<DetailedCoffeeMachineState> {
        var states = Set<DetailedCoffeeMachineState>()
        
        for mode in [DetailedCoffeeMachineState.Mode.idle, 
                     .brewing, .dispensing, .maintenance, .error] {
            // We use a simplified version with fewer possible values
            // for water and beans to keep the state space manageable
            for waterLevel in [0, 50, 100] {
                for beansLevel in [0, 50, 100] {
                    for cupCount in [0, 5, 10] {
                        if mode == .error {
                            // Add various error states
                            for errorCode in [1, 2, 3] {
                                let state = DetailedCoffeeMachineState(
                                    mode: mode,
                                    waterLevel: waterLevel,
                                    beansLevel: beansLevel,
                                    cupCount: cupCount,
                                    errorCode: errorCode
                                )
                                states.insert(state)
                            }
                        } else {
                            // Add non-error states
                            let state = DetailedCoffeeMachineState(
                                mode: mode,
                                waterLevel: waterLevel,
                                beansLevel: beansLevel,
                                cupCount: cupCount,
                                errorCode: nil
                            )
                            states.insert(state)
                        }
                    }
                }
            }
        }
        
        return states
    }
    
    // Define initial states
    var initialStates: Set<DetailedCoffeeMachineState> {
        return Set([
            DetailedCoffeeMachineState(
                mode: .idle,
                waterLevel: 100,
                beansLevel: 100,
                cupCount: 0,
                errorCode: nil
            )
        ])
    }
    
    // Define successors based on the state's attributes and possible transitions
    func successors(of state: DetailedCoffeeMachineState) -> Set<DetailedCoffeeMachineState> {
        var successors = Set<DetailedCoffeeMachineState>()
        
        switch state.mode {
        case .idle:
            // From idle, we can start brewing if resources are available
            if state.waterLevel > 0 && state.beansLevel > 0 {
                successors.insert(DetailedCoffeeMachineState(
                    mode: .brewing,
                    waterLevel: state.waterLevel,
                    beansLevel: state.beansLevel,
                    cupCount: state.cupCount,
                    errorCode: nil
                ))
            }
            
            // We can also go to maintenance mode
            successors.insert(DetailedCoffeeMachineState(
                mode: .maintenance,
                waterLevel: state.waterLevel,
                beansLevel: state.beansLevel,
                cupCount: state.cupCount,
                errorCode: nil
            ))
            
            // If water or beans are low, we might get an error
            if state.waterLevel == 0 || state.beansLevel == 0 {
                successors.insert(DetailedCoffeeMachineState(
                    mode: .error,
                    waterLevel: state.waterLevel,
                    beansLevel: state.beansLevel,
                    cupCount: state.cupCount,
                    errorCode: 1 // Resource error
                ))
            }
            
            // Add more successor states as needed...
            
        case .brewing:
            // Brewing can lead to dispensing (success) or error
            
            // Success case - transition to dispensing with decreased resources
            successors.insert(DetailedCoffeeMachineState(
                mode: .dispensing,
                waterLevel: max(0, state.waterLevel - 50),
                beansLevel: max(0, state.beansLevel - 50),
                cupCount: state.cupCount,
                errorCode: nil
            ))
            
            // Error case
            successors.insert(DetailedCoffeeMachineState(
                mode: .error,
                waterLevel: state.waterLevel,
                beansLevel: state.beansLevel,
                cupCount: state.cupCount,
                errorCode: 2 // Brewing error
            ))
            
        // Handle other state transitions similarly...
        case .dispensing:
            // After dispensing, return to idle and increment cup count
            successors.insert(DetailedCoffeeMachineState(
                mode: .idle,
                waterLevel: state.waterLevel,
                beansLevel: state.beansLevel,
                cupCount: state.cupCount + 1,
                errorCode: nil
            ))
            
        case .maintenance:
            // After maintenance, go back to idle with refilled resources
            successors.insert(DetailedCoffeeMachineState(
                mode: .idle,
                waterLevel: 100,
                beansLevel: 100,
                cupCount: 0, // Reset cup count after maintenance
                errorCode: nil
            ))
            
        case .error:
            // From error, we can reset to idle
            successors.insert(DetailedCoffeeMachineState(
                mode: .idle,
                waterLevel: state.waterLevel,
                beansLevel: state.beansLevel,
                cupCount: state.cupCount,
                errorCode: nil
            ))
            
            // Or we can go to maintenance
            successors.insert(DetailedCoffeeMachineState(
                mode: .maintenance,
                waterLevel: state.waterLevel,
                beansLevel: state.beansLevel,
                cupCount: state.cupCount,
                errorCode: nil
            ))
        }
        
        return successors
    }
    
    // Define atomic propositions
    func atomicPropositionsTrue(in state: DetailedCoffeeMachineState) -> Set<String> {
        var props = Set<String>()
        
        // Add propositions based on mode
        switch state.mode {
        case .idle:
            props.insert("isIdle")
            
            if state.waterLevel > 0 && state.beansLevel > 0 {
                props.insert("isReady")
            }
            
        case .brewing:
            props.insert("isBrewing")
            props.insert("isWorking")
            
        case .dispensing:
            props.insert("isDispensing")
            props.insert("isWorking")
            
        case .maintenance:
            props.insert("inMaintenance")
            
        case .error:
            props.insert("hasError")
            
            if let errorCode = state.errorCode {
                props.insert("errorCode_\(errorCode)")
            }
        }
        
        // Add propositions based on resource levels
        if state.waterLevel == 0 {
            props.insert("waterEmpty")
        } else if state.waterLevel < 50 {
            props.insert("waterLow")
        }
        
        if state.beansLevel == 0 {
            props.insert("beansEmpty")
        } else if state.beansLevel < 50 {
            props.insert("beansLow")
        }
        
        // Add proposition for cup count
        if state.cupCount >= 10 {
            props.insert("needsEmptying")
        }
        
        return props
    }
}
```

## 4. Creating Propositions for Verification

Now we can create propositions to verify properties of our state machine:

```swift
// Create propositions for basic coffee machine
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "Machine is idle",
    evaluate: { (state: CoffeeMachineState) -> Bool in
        return state == .idle
    }
)

let isWorking = TemporalKit.makeProposition(
    id: "isWorking",
    name: "Machine is working",
    evaluate: { (state: CoffeeMachineState) -> Bool in
        return state == .brewing || state == .dispensing
    }
)

let needsAttention = TemporalKit.makeProposition(
    id: "needsAttention",
    name: "Machine needs attention",
    evaluate: { (state: CoffeeMachineState) -> Bool in
        return state == .waterEmpty || state == .maintainRequired || state == .error
    }
)
```

## 5. Verifying Properties of the State Machine

Once we have a Kripke structure and propositions, we can verify properties:

```swift
// Create the model
let coffeeMachineModel = CoffeeMachineModel()

// Create a model checker
let modelChecker = LTLModelChecker<CoffeeMachineModel>()

// Define properties to verify

// Property 1: After brewing, the machine eventually dispenses coffee
let eventuallyDispensesAfterBrewing = LTLFormula<ClosureTemporalProposition<CoffeeMachineState, Bool>>.globally(
    .implies(
        .atomic(isBrewing),
        .eventually(.atomic(isDispensing))
    )
)

// Property 2: The machine can always return to idle state
let alwaysReturnsToIdle = LTLFormula<ClosureTemporalProposition<CoffeeMachineState, Bool>>.globally(
    .eventually(.atomic(isIdle))
)

// Property 3: Working states are always followed by either idle or an error
let workingThenIdleOrError = LTLFormula<ClosureTemporalProposition<CoffeeMachineState, Bool>>.globally(
    .implies(
        .atomic(isWorking),
        .next(.or(.atomic(isIdle), .atomic(isError)))
    )
)

// Verify properties
do {
    let result1 = try modelChecker.check(formula: eventuallyDispensesAfterBrewing, model: coffeeMachineModel)
    print("Property 1 (Eventually dispenses after brewing): \(result1)")
    
    let result2 = try modelChecker.check(formula: alwaysReturnsToIdle, model: coffeeMachineModel)
    print("Property 2 (Always returns to idle): \(result2)")
    
    let result3 = try modelChecker.check(formula: workingThenIdleOrError, model: coffeeMachineModel)
    print("Property 3 (Working then idle or error): \(result3)")
} catch {
    print("Verification error: \(error)")
}
```

## 6. Modeling SwiftUI View State Machines

TemporalKit can also be used to model and verify SwiftUI view state machines:

```swift
// Define states for a registration form
enum RegistrationFormState: Hashable {
    case initial
    case fillingPersonalInfo
    case fillingContactInfo
    case validating
    case submitting
    case success
    case error(String)
}

// Define the state machine
struct RegistrationFormModel: KripkeStructure {
    typealias State = RegistrationFormState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<RegistrationFormState>
    let initialStates: Set<RegistrationFormState> = [.initial]
    
    init() {
        // Create the set of all states
        var states: Set<RegistrationFormState> = [
            .initial, .fillingPersonalInfo, .fillingContactInfo,
            .validating, .submitting, .success
        ]
        
        // Add error states
        let errorMessages = ["Invalid email", "Network error", "Server error"]
        for message in errorMessages {
            states.insert(.error(message))
        }
        
        self.allStates = states
    }
    
    func successors(of state: RegistrationFormState) -> Set<RegistrationFormState> {
        switch state {
        case .initial:
            return [.fillingPersonalInfo]
            
        case .fillingPersonalInfo:
            return [.fillingContactInfo]
            
        case .fillingContactInfo:
            return [.validating]
            
        case .validating:
            return [.submitting, .error("Invalid email")]
            
        case .submitting:
            return [.success, .error("Network error"), .error("Server error")]
            
        case .success:
            return [.initial] // Start over
            
        case .error:
            return [.initial, .fillingPersonalInfo, .fillingContactInfo]
        }
    }
    
    func atomicPropositionsTrue(in state: RegistrationFormState) -> Set<String> {
        switch state {
        case .initial:
            return ["isInitial"]
            
        case .fillingPersonalInfo:
            return ["isFillingForm", "isPersonalInfo"]
            
        case .fillingContactInfo:
            return ["isFillingForm", "isContactInfo"]
            
        case .validating:
            return ["isProcessing", "isValidating"]
            
        case .submitting:
            return ["isProcessing", "isSubmitting"]
            
        case .success:
            return ["isCompleted", "isSuccess"]
            
        case .error(let message):
            return ["isError", "errorMessage_\(message.replacingOccurrences(of: " ", with: "_"))"]
        }
    }
}

// Create propositions
let isFillingForm = TemporalKit.makeProposition(
    id: "isFillingForm",
    name: "User is filling the form",
    evaluate: { (state: RegistrationFormState) -> Bool in
        switch state {
        case .fillingPersonalInfo, .fillingContactInfo:
            return true
        default:
            return false
        }
    }
)

let isProcessing = TemporalKit.makeProposition(
    id: "isProcessing",
    name: "Form is being processed",
    evaluate: { (state: RegistrationFormState) -> Bool in
        switch state {
        case .validating, .submitting:
            return true
        default:
            return false
        }
    }
)

let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "Form has an error",
    evaluate: { (state: RegistrationFormState) -> Bool in
        switch state {
        case .error:
            return true
        default:
            return false
        }
    }
)
```

## 7. Integrating with Real Code

Let's see how to integrate this verification with actual SwiftUI view code:

```swift
// A view model that uses the verified state machine
class RegistrationViewModel: ObservableObject {
    // The current state of the form
    @Published var state: RegistrationFormState = .initial
    
    // Model for verification
    private let stateModel = RegistrationFormModel()
    
    // State transition function
    func transition(to newState: RegistrationFormState) {
        // Verify that this is a valid transition
        let validNextStates = stateModel.successors(of: state)
        
        guard validNextStates.contains(newState) else {
            print("Error: Invalid state transition from \(state) to \(newState)")
            // Could automatically go to error state instead
            // state = .error("Invalid state transition")
            return
        }
        
        // Perform the transition since it's valid
        state = newState
    }
    
    // Action handlers
    func startPersonalInfo() {
        transition(to: .fillingPersonalInfo)
    }
    
    func moveToContactInfo() {
        transition(to: .fillingContactInfo)
    }
    
    func submitForm() {
        transition(to: .validating)
        
        // Simulate validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            // Randomly succeed or fail validation
            if Bool.random() {
                self?.transition(to: .submitting)
                
                // Simulate submission
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    // Randomly succeed or fail submission
                    if Bool.random() {
                        self?.transition(to: .success)
                    } else {
                        self?.transition(to: .error("Network error"))
                    }
                }
            } else {
                self?.transition(to: .error("Invalid email"))
            }
        }
    }
    
    func reset() {
        transition(to: .initial)
    }
}

// Usage in SwiftUI view
struct RegistrationFormView: View {
    @ObservedObject var viewModel = RegistrationViewModel()
    
    var body: some View {
        VStack {
            // Display different content based on the state
            switch viewModel.state {
            case .initial:
                Button("Start Registration") {
                    viewModel.startPersonalInfo()
                }
                
            case .fillingPersonalInfo:
                Text("Personal Information")
                // Form fields would go here
                Button("Next") {
                    viewModel.moveToContactInfo()
                }
                
            case .fillingContactInfo:
                Text("Contact Information")
                // Form fields would go here
                Button("Submit") {
                    viewModel.submitForm()
                }
                
            case .validating:
                ProgressView("Validating...")
                
            case .submitting:
                ProgressView("Submitting...")
                
            case .success:
                VStack {
                    Text("Registration Successful!")
                    Button("Start Over") {
                        viewModel.reset()
                    }
                }
                
            case .error(let message):
                VStack {
                    Text("Error: \(message)")
                    Button("Try Again") {
                        viewModel.reset()
                    }
                }
            }
        }
        .padding()
    }
}
```

## 8. Hierarchical State Machines

For more complex UIs, you can model hierarchical state machines:

```swift
// Define a hierarchical state machine for a multi-screen app
enum AppScreen: Hashable {
    case launch
    case onboarding(OnboardingStep)
    case authentication(AuthStep)
    case main(MainTab)
    case settings(SettingsPage)
    
    enum OnboardingStep: Hashable {
        case welcome
        case featureIntro
        case permissionsRequest
        case accountSetup
        case complete
    }
    
    enum AuthStep: Hashable {
        case loginPrompt
        case registration
        case passwordReset
        case twoFactorAuth
        case biometricPrompt
    }
    
    enum MainTab: Hashable {
        case home
        case search
        case profile
        case notifications
        case newContent
    }
    
    enum SettingsPage: Hashable {
        case main
        case account
        case privacy
        case notifications
        case appearance
        case about
    }
}

// Implement the state machine
struct AppNavigationModel: KripkeStructure {
    typealias State = AppScreen
    typealias AtomicPropositionIdentifier = String
    
    // For brevity, we'll only implement a subset of states and transitions
    
    let initialStates: Set<State> = [.launch]
    
    // In a real implementation, you would define all possible states
    var allStates: Set<State> {
        var states: Set<State> = [.launch]
        
        // Add onboarding states
        for step in [AppScreen.OnboardingStep.welcome, .featureIntro, 
                     .permissionsRequest, .accountSetup, .complete] {
            states.insert(.onboarding(step))
        }
        
        // Add authentication states
        for step in [AppScreen.AuthStep.loginPrompt, .registration, 
                     .passwordReset, .twoFactorAuth, .biometricPrompt] {
            states.insert(.authentication(step))
        }
        
        // Add main tab states
        for tab in [AppScreen.MainTab.home, .search, .profile, 
                    .notifications, .newContent] {
            states.insert(.main(tab))
        }
        
        // Add settings states
        for page in [AppScreen.SettingsPage.main, .account, .privacy, 
                     .notifications, .appearance, .about] {
            states.insert(.settings(page))
        }
        
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .launch:
            // From launch, go to onboarding or auth
            return [.onboarding(.welcome), .authentication(.loginPrompt)]
            
        case .onboarding(let step):
            switch step {
            case .welcome:
                return [.onboarding(.featureIntro)]
            case .featureIntro:
                return [.onboarding(.permissionsRequest)]
            case .permissionsRequest:
                return [.onboarding(.accountSetup)]
            case .accountSetup:
                return [.onboarding(.complete)]
            case .complete:
                return [.authentication(.loginPrompt)]
            }
            
        case .authentication(let step):
            switch step {
            case .loginPrompt:
                return [.authentication(.registration), 
                        .authentication(.passwordReset),
                        .authentication(.biometricPrompt),
                        .main(.home)]
            case .registration:
                return [.authentication(.loginPrompt)]
            case .passwordReset:
                return [.authentication(.loginPrompt)]
            case .twoFactorAuth:
                return [.main(.home)]
            case .biometricPrompt:
                return [.authentication(.loginPrompt), .main(.home)]
            }
            
        case .main(let tab):
            var successors: Set<State> = []
            
            // From any tab, can go to any other tab
            for potentialTab in [AppScreen.MainTab.home, .search, 
                                 .profile, .notifications, .newContent] {
                if potentialTab != tab {
                    successors.insert(.main(potentialTab))
                }
            }
            
            // From any tab, can go to settings
            successors.insert(.settings(.main))
            
            return successors
            
        case .settings(let page):
            switch page {
            case .main:
                // From main settings, can go to any specific settings page or back to main app
                var successors: Set<State> = []
                
                for specificPage in [AppScreen.SettingsPage.account, .privacy, 
                                     .notifications, .appearance, .about] {
                    successors.insert(.settings(specificPage))
                }
                
                // Can also go back to main app
                successors.insert(.main(.home))
                
                return successors
                
            default:
                // From any specific settings page, can go back to main settings
                return [.settings(.main)]
            }
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<String> {
        var props: Set<String> = []
        
        switch state {
        case .launch:
            props.insert("isLaunch")
            
        case .onboarding(let step):
            props.insert("isOnboarding")
            props.insert("onboarding_\(step)")
            
        case .authentication(let step):
            props.insert("isAuthentication")
            props.insert("auth_\(step)")
            
        case .main(let tab):
            props.insert("isMainApp")
            props.insert("tab_\(tab)")
            
        case .settings(let page):
            props.insert("isSettings")
            props.insert("settings_\(page)")
        }
        
        return props
    }
}
```

## Conclusion

This tutorial has shown how to model state machines using TemporalKit's Kripke structure concept. By representing your application's states and transitions formally, you can verify important properties and ensure correct behavior before implementation.

Key takeaways:

1. State machines can be modeled as Kripke structures in TemporalKit
2. You can verify temporal properties of your state machines using LTL formulas
3. This approach works well for UI flows, form validation, and other stateful behaviors
4. The verification can be integrated with your actual SwiftUI code

In the next tutorial, we'll explore common LTL patterns that are useful for expressing properties of your state machines. 
