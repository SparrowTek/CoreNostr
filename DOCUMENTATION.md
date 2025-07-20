# CoreNostr Documentation

This document describes how to build and view the CoreNostr documentation.

## Building Documentation

CoreNostr uses Swift DocC for documentation. To build the documentation:

### Using Xcode

1. Open the CoreNostr package in Xcode
2. Select Product → Build Documentation (⌃⇧⌘D)
3. The documentation will open in the Developer Documentation window

### Using Swift Package Manager

```bash
# Build documentation
swift package generate-documentation

# Build and preview in browser
swift package --disable-sandbox preview-documentation --target CoreNostr
```

### Using Docker (for CI/CD)

```bash
docker run -v "$PWD:/workspace" -w /workspace swift:latest \
    swift package generate-documentation \
    --target CoreNostr \
    --output-path ./docs
```

## Documentation Structure

The documentation is organized as follows:

```
Sources/CoreNostr/Documentation.docc/
├── CoreNostr.md              # Main documentation catalog
├── Tutorials/
│   └── GettingStarted.md     # Step-by-step tutorials
├── Articles/
│   └── WorkingWithEncryption.md  # In-depth articles
└── Resources/
    └── Info.plist            # Documentation metadata
```

## Documentation Guidelines

When adding new documentation:

1. **Use DocC syntax** for all public APIs:
   ```swift
   /// Brief description of the function.
   ///
   /// Detailed explanation of what the function does.
   ///
   /// - Parameters:
   ///   - param1: Description of parameter 1
   ///   - param2: Description of parameter 2
   /// - Returns: Description of return value
   /// - Throws: Description of errors that can be thrown
   ```

2. **Add code examples** where appropriate:
   ```swift
   /// ## Example
   /// ```swift
   /// let result = try someFunction(param1: "value")
   /// print(result)
   /// ```
   ```

3. **Link to related symbols** using double backticks:
   ```swift
   /// Uses ``NostrEvent`` to create the event.
   /// See also ``KeyPair`` for key management.
   ```

4. **Group related functionality** using MARK comments:
   ```swift
   // MARK: - Public Methods
   ```

## Viewing Documentation

### Local Development

After building documentation, you can:
- View it in Xcode's Developer Documentation window
- Export it as a `.doccarchive` for distribution
- Host it on a web server using the `preview-documentation` command

### Online Documentation

The documentation can be hosted on:
- GitHub Pages (using CI/CD)
- Swift Package Index
- Your own documentation server

## Writing Good Documentation

### For Public APIs

Every public type, method, and property should have:
- A brief, one-sentence summary
- A detailed description (if needed)
- Parameter descriptions (for methods)
- Return value description (if applicable)
- Example usage (for complex APIs)
- Links to related types/methods

### For Tutorials

Tutorials should:
- Start with prerequisites
- Use progressive disclosure
- Include complete, runnable code examples
- Explain the "why" not just the "how"
- End with next steps

### For Articles

Articles should:
- Focus on a specific topic or use case
- Provide in-depth explanations
- Include best practices
- Show real-world examples
- Discuss trade-offs and alternatives

## Maintaining Documentation

1. **Update documentation** when changing public APIs
2. **Test code examples** to ensure they compile
3. **Review documentation** in pull requests
4. **Keep tutorials current** with API changes
5. **Add documentation** for new features

## Common DocC Features

### Code Voice
Use single backticks for inline code: `EventKind.textNote`

### Symbol Links
Use double backticks for symbol links: ``NostrEvent``

### Note Callouts
```
> Note: Important information for users
```

### Warning Callouts
```
> Warning: Critical information about potential issues
```

### Important Callouts
```
> Important: Key information that users should know
```

### Code Listings
````swift
```swift
// Code examples with syntax highlighting
let event = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, Nostr!"
)
```
````

## Contributing Documentation

When contributing to CoreNostr:
1. Add/update documentation for any public API changes
2. Ensure examples compile and work correctly
3. Follow the existing documentation style
4. Check that documentation builds without warnings

## Resources

- [Swift DocC Documentation](https://www.swift.org/documentation/docc/)
- [DocC Tutorial](https://www.swift.org/documentation/docc/tutorial)
- [Apple's DocC Guide](https://developer.apple.com/documentation/docc)