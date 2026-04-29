import Testing
import Foundation
@testable import IntegrationTests

@Suite struct IntegrationTestsTests {
    
    @Test func gettingTests() throws {
        let testResources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources")
        let tests = try getTests(
            in: testResources,
            usingEnvironmentVariables: false // keeping the references to the environment variables for this test!
        )
        #expect(
            tests == [
                LocatedIntegrationTest(
                    relativeDirectory: "tests/1",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        executable: "$EXECUTABLE",
                        arguments: ["$FILE1", "$FILE2"]
                    )
                ),
                LocatedIntegrationTest(
                    relativeDirectory: "tests/2",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        executable: "$EXECUTABLE",
                        arguments: ["$FILE1", "$FILE2"]
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
