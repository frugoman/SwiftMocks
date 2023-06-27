# Mockable

A Swift library for easily mocking out objects.

Using Swift Macros, Mockable allows you to easily create mock objects for testing. It's as simple as adding the `@Mock` attribute to your class, and then calling the generated `mock` property.

The `mock` property keeps track of all calls to the object, and allows you to easily verify that the object was called with the correct parameters and to effortlessly stub out return values.

## Usage

### Mocking

To mock an object, simply add the `@Mock` attribute to your class. This will generate a `mock` property on your class that you can use to verify calls to the object.

```swift
// This is the class we want to mock
class MyObject {
    func doSomething() {}
}

@Mock
class MyObject {
    func doSomething() {
        mock.doSomething()
    }
    let mock = MyObjectMockable() // generated
    class MyObjectMockable { // generated
        var doSomethingCalls: Mockable<Void, Void> = .init() // generated
        func doSomething() { // generated
            doSomethingCalls.record(()) // generated
        } // generated
    } // generated
}
```

### Stubbing Return Values

To stub out return values, simply call the `mockCall` method on the `mock` property.

```swift
// This is the class we want to mock
class MyObject {
    func doSomething() -> Int { 
        mock.doSomething()
    }
}

@Mock
class MyObject {
    func doSomething() -> Int {
        mock.doSomething()
    }
}

let myObject = MyObject()
myObject.mock.doSomethingCalls.mockCall { 1 }

print(myObject.doSomething()) // this prints 1
```

### Verifying Calls

To verify that a method was called, simply call the `verify` method on the `mock` property.

```swift
// This is the class we want to mock
class MyObject {
    func doSomething() {}
}

@Mock
class MyObject {
    func doSomething(param: Int) {
        mock.doSomething(param: param)
    }
}

let myObject = MyObject()
myObject.doSomething(param: 999)

XCTAssertEqual(myObject.mock.doSomethingCalls.callCount, 1)
XCTAssertEqual(myObject.mock.doSomethingCalls.lastCall?.0, 999)
```

## Taking advantage in tests

In your production code, you'd define your protocols and classes as normal. In your tests, you'd add the `@Mock` to the Mock class, and then use the `mock` property to verify calls.

```swift
// production code
protocol Service {
    func doSomething() -> String 
}

class RealService: Service {
    func doSomething() -> String {
        return "yes!"// production code
    }
}

let service: Service = RealService()
let useCase = UseCase(service: service)
--------------------

// test code
@Mock
class MockService: Service {
    func doSomething() -> String {
        mock.doSomething()
    }
}

func test() {
    // Given
    let mockService = MockService()
    let sut = UseCase(service: mockService)
    mockService.mock.doSomethingCalls.mockCall { "no!" }

    // When
    let result = sut.doSomething()

    // Then
    XCTAssertEqual(result, "no!")
    XCTAssertEqual(mockService.mock.doSomethingCalls.callCount, 1)
}
```
