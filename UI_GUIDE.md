# UI Screenshots and Visual Guide

## App Interface

### Online State
```
╔══════════════════════════════════════╗
║                                      ║
║          Light Green Background      ║
║                                      ║
║                                      ║
║              📶  WiFi                ║
║          (Green, size 100)           ║
║                                      ║
║                                      ║
║              Online                  ║
║          (Green, size 48)            ║
║                                      ║
║                                      ║
║             via WiFi                 ║
║          (Gray, size 20)             ║
║                                      ║
║                                      ║
╚══════════════════════════════════════╝
```

### Offline State
```
╔══════════════════════════════════════╗
║                                      ║
║          Light Red Background        ║
║                                      ║
║                                      ║
║              📵  WiFi Slash          ║
║          (Red, size 100)             ║
║                                      ║
║                                      ║
║             Offline                  ║
║          (Red, size 48)              ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
╚══════════════════════════════════════╝
```

## Color Scheme

### Online (Connected)
- Background: `Color.green.opacity(0.3)` - Light green tint
- Icon: `Color.green` - Solid green
- Text: `Color.green` - Solid green
- Connection Type: `Color.secondary` - System secondary color

### Offline (Disconnected)
- Background: `Color.red.opacity(0.3)` - Light red tint
- Icon: `Color.red` - Solid red
- Text: `Color.red` - Solid red
- Connection Type: Hidden

## SF Symbols Used

- `wifi` - WiFi connected icon
- `wifi.slash` - WiFi disconnected icon

## Layout Details

- **Spacing**: 30pt between elements in VStack
- **Icon Size**: 100pt system font
- **Status Text Size**: 48pt bold system font
- **Connection Type Text Size**: Title2 font style
- **Background**: Fills entire screen with `ignoresSafeArea()`

## State Transitions

The app smoothly transitions between states:

1. **Online → Offline**
   - Background fades from green to red
   - Icon changes from wifi to wifi.slash
   - Text changes from "Online" to "Offline"
   - Connection type text fades out

2. **Offline → Online**
   - Background fades from red to green
   - Icon changes from wifi.slash to wifi
   - Text changes from "Offline" to "Online"
   - Connection type text fades in

## Connection Types Display

When online, the app shows one of these messages:
- "via WiFi" - When connected through WiFi
- "via Cellular" - When connected through cellular data
- "via Ethernet" - When connected through ethernet (iPad with adapter)
- "Connected" - When connection type cannot be determined

## Accessibility

The app is designed with accessibility in mind:
- Large, readable text (48pt for status)
- High contrast colors (green/red on light backgrounds)
- Clear visual indicators (icons + text)
- SF Symbols automatically scale with Dynamic Type
- VoiceOver friendly with semantic labels

## Landscape Mode

The app supports both portrait and landscape orientations:
- Layout automatically adjusts to screen size
- Elements remain centered
- Background color extends to edges
- Icon and text sizes remain consistent

## Dark Mode

The app automatically adapts to Dark Mode:
- System colors (`.green`, `.red`, `.secondary`) adjust automatically
- Background opacity remains at 0.3 for both light and dark modes
- Icon colors remain vibrant and visible
- Text colors maintain proper contrast
