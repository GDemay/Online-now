# Contributing to Online Now

Thank you for considering contributing to Online Now! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- iOS version and device model
- Screenshots if applicable

### Suggesting Features

We're open to feature suggestions that align with the app's core vision. Please open an issue with:
- A clear description of the feature
- The problem it solves
- How it fits with the app's privacy-first philosophy
- Mockups or examples if applicable

### Code Contributions

#### Before You Start

1. Check existing issues and pull requests
2. Open an issue to discuss major changes
3. Ensure your contribution aligns with the app's vision

#### Development Setup

1. Fork the repository
2. Clone your fork
3. Open `OnlineNow.xcodeproj` in Xcode
4. Build and run on simulator or device

#### Coding Guidelines

**Swift Style**
- Follow Swift API Design Guidelines
- Use Swift naming conventions
- Write clear, self-documenting code
- Add comments for complex logic only

**SwiftUI Best Practices**
- Use declarative syntax
- Keep views small and focused
- Extract reusable components
- Use proper state management

**Architecture**
- Follow MVVM pattern
- Keep models pure (no logic)
- Put business logic in services/view models
- Keep views lightweight

**Accessibility**
- All UI elements must have accessibility labels
- Support Dynamic Type
- Test with VoiceOver
- Ensure sufficient color contrast

**Privacy**
- Never add analytics or tracking
- No third-party SDKs that collect data
- All data must stay on device
- Document any network requests

#### Testing

Before submitting:
- [ ] Code builds without warnings
- [ ] App runs on iOS 15.0+
- [ ] Tested on multiple device sizes
- [ ] Tested with VoiceOver
- [ ] Tested with largest Dynamic Type size
- [ ] No crashes or hangs
- [ ] Privacy principles maintained

#### Pull Request Process

1. Create a feature branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the coding guidelines

3. Test thoroughly on device and simulator

4. Commit with clear, descriptive messages
   ```bash
   git commit -m "Add feature: clear description"
   ```

5. Push to your fork
   ```bash
   git push origin feature/your-feature-name
   ```

6. Open a pull request with:
   - Clear title and description
   - Screenshots/videos of changes
   - Testing notes
   - Any related issues

7. Respond to feedback and make requested changes

8. Once approved, your PR will be merged!

## Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behavior**:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards others

**Unacceptable behavior**:
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

### Enforcement

Violations may result in:
- Warning
- Temporary ban
- Permanent ban

Report violations by opening an issue or contacting maintainers.

## Development Priorities

### High Priority
- Bug fixes
- Accessibility improvements
- Performance optimizations
- Privacy enhancements

### Medium Priority
- UI/UX improvements
- Additional test coverage
- Documentation improvements
- Localization support

### Low Priority (Consider Carefully)
- New features (must align with core vision)
- UI theming options
- Export capabilities

### Won't Accept
- Analytics or tracking
- Background monitoring
- Push notifications
- Account systems
- Cloud sync
- Third-party SDKs that collect data
- Features that compromise privacy

## Questions?

Open an issue or start a discussion on GitHub.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make Online Now better! 🚀
