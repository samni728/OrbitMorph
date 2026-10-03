import Foundation

public enum ImageMagickAdapter {
    public static func invocation(input: URL, output: URL, target: FormatID, magickPath: String) -> ProcessInvocation {
        var args = [input.path]
        if target == .jpg { args += ["-quality", "92"] }
        if target == .webp { args += ["-quality", "88"] }
        args.append(output.path)
        return .init(executable: magickPath, arguments: args)
    }
}
