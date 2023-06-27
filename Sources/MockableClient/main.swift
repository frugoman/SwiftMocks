import Mockable

@Mock class MyClass {
    var priority: Int { mock.priority.getter.record() }
    func doSomething() { mock.doSomething() }
    func perform(with param: Int) -> String {
        mock.perform(with: param)
    }
}

let myClass = MyClass()
myClass.mock.priority.getter.mockCall { 1 }
print(myClass.priority) // prints `1`
myClass.doSomething()
print(myClass.mock.doSomethingCalls.callsCount == 1) // prints `true`
myClass.mock.performCalls.mockCall { param in "mocked => \(param)" }
print(myClass.perform(with: 1)) // prints `mocked => 1`
