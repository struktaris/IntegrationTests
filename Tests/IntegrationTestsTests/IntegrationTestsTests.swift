import Testing
import Foundation
@testable import IntegrationTests

@Suite struct IntegrationTestsTests {
    
    @Test func gettingTests() throws {
        let testResources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources")
        let tests = try getTests(in: testResources)
        #expect(
            tests == [
                LocatedIntegrationTest(
                    relativeDirectory: "tests/1",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        environmentVariableForExecutable: "EXECUTABLE1",
                        arguments: ["a.txt", "b.txt"]
                    )
                ),
                LocatedIntegrationTest(
                    relativeDirectory: "tests/2",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        environmentVariableForExecutable: "EXECUTABLE1",
                        arguments: ["a.txt", "b.txt"]
                    )
                )
            ]
        )
    }
    
    @Test func executingTests() async throws {
        let testResources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources")
        print()
        let differentFilesForTests = try await executeTests(in: testResources)
        print()
        print(differentFilesForTests)
        #expect(differentFilesForTests == ["tests/1": [], "tests/2": ["b.txt"]])
        print()
    }
    
}
