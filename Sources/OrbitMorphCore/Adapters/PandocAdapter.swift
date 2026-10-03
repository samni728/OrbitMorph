import Foundation

public enum PandocAdapter {
    public static func invocation(input: URL, output: URL, pandocPath: String) -> ProcessInvocation {
        .init(executable: pandocPath, arguments: [input.path, "-o", output.path])
    }
}
