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
                        arguments: ["$FILE1", "$FILE2"],
                        ignore: [".gitignore", ".DS_Store", "Thumbs.db", "*.log"]
                    )
                ),
                LocatedIntegrationTest(
                    relativeDirectory: "tests/2",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        executable: "$EXECUTABLE",
                        arguments: ["$FILE1", "$FILE2"],
                        ignore: [".gitignore", ".DS_Store", "Thumbs.db", "*.log"]
                    )
                )
            ]
        )
    }
    
    @Test func directoryComparison() throws {
        let comparisonTests = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources").appending(component: "comparisonTests")
        
        func doIt(ignoreEmptyDirectories: Bool) throws -> [String] {
            try differentFiles(
                in: comparisonTests.appending(component: "test"),
                comparedTo: comparisonTests.appending(component: "reference"),
                ignoreEmptyDirectories: ignoreEmptyDirectories,
                ignore: { [".gitignore", ".DS_Store", "Thumbs.db"].contains($0) }
            ).sorted(by: { $0.compare($01, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending})
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: true)
            #expect(result == ["2.txt", "a/a3.txt", "a/aa/aa2.txt", "x"])
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: false)
            #expect(result == ["2.txt", "a/a3.txt", "a/aa/aa2.txt", "a/ab", "c", "d", "x"])
        }
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
