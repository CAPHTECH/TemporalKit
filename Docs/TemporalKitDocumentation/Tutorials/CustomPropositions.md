# Creating Custom Propositions

This tutorial explains how to create custom temporal propositions in TemporalKit. Propositions are the basic building blocks of LTL formulas, representing statements about your system that can be true or false in different states.

## Prerequisites

Before starting this tutorial, make sure you have:

- Completed the [Basic Usage](./BasicUsage.md) tutorial
- Understood the concept of temporal propositions
- Imported TemporalKit in your project

## Understanding Temporal Propositions

In TemporalKit, a temporal proposition is anything that conforms to the `TemporalProposition` protocol. This protocol requires:

- An `ID` type: Used to identify the proposition
- An `Input` type: The type of state or context the proposition evaluates against
- A `Value` type: The result type (typically `Bool` for LTL formulas)
- An `evaluate` method: Determines the truth value of the proposition in a given state

The built-in `ClosureTemporalProposition` type is convenient for most use cases, but you can create custom proposition types for more complex scenarios.

## 1. Using the Convenient Factory Method

The easiest way to create a proposition is using the `makeProposition` factory method:

```swift
import TemporalKit

// Define a simple state type
enum TrafficLightState: Hashable {
    case red
    case yellow
    case green
}

// Create propositions using the factory method
let isRed = TemporalKit.makeProposition(
    id: "isRed",
    name: "Light is red",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .red
    }
)

let isGreen = TemporalKit.makeProposition(
    id: "isGreen",
    name: "Light is green",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .green
    }
)
```

This approach is perfect for simple propositions that check state values.

## 2. Creating a Custom Proposition Type

For more complex propositions, you can create a custom type that conforms to `TemporalProposition`:

```swift
// A custom proposition that checks if a traffic light is safe for pedestrians
struct PedestrianSafeProposition: TemporalProposition {
    typealias Input = TrafficLightState
    typealias Value = Bool
    typealias ID = String
    
    let id: String
    let name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    func evaluate(with context: some EvaluationContext<TrafficLightState>) throws -> Bool {
        let state = context.input
        // Pedestrians can safely cross when the light is red (for cars)
        return state == .red
    }
}

// Create an instance
let pedestrianSafe = PedestrianSafeProposition(id: "pedestrianSafe", name: "Safe for pedestrians to cross")
```

## 3. Propositions with Historical State

One advantage of custom proposition types is the ability to consider historical state information:

```swift
// A proposition that detects a transition from yellow to red
struct YellowToRedTransitionProposition: TemporalProposition {
    typealias Input = TrafficLightState
    typealias Value = Bool
    typealias ID = String
    
    let id: String
    let name: String
    
    // Keep track of the previous state
    private var previousState: TrafficLightState?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    func evaluate(with context: some EvaluationContext<TrafficLightState>) throws -> Bool {
        let currentState = context.input
        
        // Check if this is a transition from yellow to red
        let result = previousState == .yellow && currentState == .red
        
        // Update the previous state for next evaluation
        previousState = currentState
        
        return result
    }
}

// Create an instance
let yellowToRedTransition = YellowToRedTransitionProposition(
    id: "yellowToRedTransition", 
    name: "Transition from yellow to red"
)
```

## 4. Parameterized Propositions

You can create propositions that are parameterized, making them more reusable:

```swift
// A parameterized proposition factory for checking traffic light state
func makeTrafficLightProposition(
    forState targetState: TrafficLightState
) -> ClosureTemporalProposition<TrafficLightState, Bool> {
    return TemporalKit.makeProposition(
        id: "is\(targetState)",
        name: "Light is \(targetState)",
        evaluate: { (state: TrafficLightState) -> Bool in
            return state == targetState
        }
    )
}

// Create propositions for all states
let isRed = makeTrafficLightProposition(forState: .red)
let isYellow = makeTrafficLightProposition(forState: .yellow)
let isGreen = makeTrafficLightProposition(forState: .green)
```

## 5. Composite Propositions

You can create propositions that combine other propositions:

```swift
// A proposition that combines other propositions
struct CompositeProposition<State>: TemporalProposition {
    typealias Input = State
    typealias Value = Bool
    typealias ID = String
    
    let id: String
    let name: String
    let propositions: [ClosureTemporalProposition<State, Bool>]
    let combiner: ([Bool]) -> Bool
    
    init(
        id: String,
        name: String,
        propositions: [ClosureTemporalProposition<State, Bool>],
        combiner: @escaping ([Bool]) -> Bool
    ) {
        self.id = id
        self.name = name
        self.propositions = propositions
        self.combiner = combiner
    }
    
    func evaluate(with context: some EvaluationContext<State>) throws -> Bool {
        // Evaluate all component propositions
        var results: [Bool] = []
        for proposition in propositions {
            let result = try proposition.evaluate(with: context)
            results.append(result)
        }
        
        // Combine the results using the provided combiner function
        return combiner(results)
    }
}

// Example: Create an "AND" composite proposition
let redOrYellow = CompositeProposition(
    id: "redOrYellow",
    name: "Light is either red or yellow",
    propositions: [isRed, isYellow],
    combiner: { results in results.contains(true) } // OR logic
)
```

## 6. Propositions with External Dependencies

Sometimes, propositions need to access external services or data:

```swift
// A proposition that uses an external service
class WeatherAwareProposition: TemporalProposition {
    typealias Input = TrafficLightState
    typealias Value = Bool
    typealias ID = String
    
    let id: String
    let name: String
    private let weatherService: WeatherService
    
    init(id: String, name: String, weatherService: WeatherService) {
        self.id = id
        self.name = name
        self.weatherService = weatherService
    }
    
    func evaluate(with context: some EvaluationContext<TrafficLightState>) throws -> Bool {
        let state = context.input
        
        // Check if it's raining
        let isRaining = weatherService.currentCondition == .rainy
        
        // Traffic light should be red longer in rainy conditions
        if isRaining && state == .red {
            return true
        }
        
        // Regular evaluation
        return state == .red
    }
}

// Mock weather service
class WeatherService {
    enum WeatherCondition {
        case sunny, rainy, cloudy
    }
    
    var currentCondition: WeatherCondition = .sunny
}

// Create the proposition with a dependency
let weatherService = WeatherService()
let weatherAwareRedLight = WeatherAwareProposition(
    id: "weatherAwareRed",
    name: "Red light considering weather conditions",
    weatherService: weatherService
)
```

## 7. Using Custom Propositions in LTL Formulas

Once you've created custom propositions, you can use them in LTL formulas:

```swift
// Create a formula using custom propositions
let safePedestrianCrossing = LTLFormula<PedestrianSafeProposition>.globally(
    .implies(
        .atomic(pedestrianSafe),
        .not(.atomic(isGreen))
    )
)

// A more complex formula using multiple custom propositions
let properLightSequence = LTLFormula<ClosureTemporalProposition<TrafficLightState, Bool>>.globally(
    .implies(
        .atomic(isGreen),
        .next(.atomic(isYellow))
    )
)
```

## 8. Testing Custom Propositions

It's good practice to test your custom propositions:

```swift
// Test propositions individually
func testProposition() {
    // Create a simple context for evaluation
    let redContext = SimpleEvaluationContext(input: TrafficLightState.red)
    let greenContext = SimpleEvaluationContext(input: TrafficLightState.green)
    
    // Test the pedestrianSafe proposition
    do {
        let resultRed = try pedestrianSafe.evaluate(with: redContext)
        let resultGreen = try pedestrianSafe.evaluate(with: greenContext)
        
        assert(resultRed == true, "Pedestrians should be safe when light is red")
        assert(resultGreen == false, "Pedestrians should not be safe when light is green")
    } catch {
        print("Error evaluating proposition: \(error)")
    }
}

// Simple evaluation context for testing
struct SimpleEvaluationContext<Input>: EvaluationContext {
    let input: Input
}
```

## Advanced Example: Timed Propositions

Here's a more advanced example that considers timing information:

```swift
// A state with timing information
struct TimedTrafficLightState: Hashable {
    let color: TrafficLightState
    let secondsInState: Int
}

// A proposition that checks if a light has been red for too long
struct LongRedLightProposition: TemporalProposition {
    typealias Input = TimedTrafficLightState
    typealias Value = Bool
    typealias ID = String
    
    let id: String
    let name: String
    let maxRedDuration: Int
    
    init(id: String, name: String, maxRedDuration: Int) {
        self.id = id
        self.name = name
        self.maxRedDuration = maxRedDuration
    }
    
    func evaluate(with context: some EvaluationContext<TimedTrafficLightState>) throws -> Bool {
        let state = context.input
        
        // Check if the light has been red for too long
        return state.color == .red && state.secondsInState > maxRedDuration
    }
}

// Create an instance
let redTooLong = LongRedLightProposition(
    id: "redTooLong",
    name: "Red light has been active too long",
    maxRedDuration: 60
)

// Use in a formula
let noExcessiveRedLights = LTLFormula<LongRedLightProposition>.globally(
    .not(.atomic(redTooLong))
)
```

## Conclusion

Custom propositions provide a powerful way to express domain-specific properties in your models. They can encapsulate complex logic, maintain state, access external services, and combine other propositions.

By creating well-designed proposition types, you can build a domain-specific language for expressing temporal properties in your application domain, making your verification code more readable and maintainable.

In the next tutorial, we'll explore how to model state machines using TemporalKit. 
