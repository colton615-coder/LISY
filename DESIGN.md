---
name: "LIFE IN SYNC"
description: "A quietly premium native personal operating system."
colors:
  garage-accent: "#FDE047"
  garage-gold: "#FABF2E"
  garage-gold-deep: "#BD780D"
  garage-emerald: "#175938"
  garage-emerald-deep: "#031A12"
  garage-emerald-glass: "#0D3826"
  garage-turf: "#2D7A3E"
  garage-surface: "#236331"
  garage-canvas: "#0D141B"
  garage-mint-text: "#A8D6B3"
  text-primary: "#FFFFFF"
typography:
  display:
    fontFamily: "SF Pro Rounded, SF Pro Display, system-ui"
    fontSize: "58pt"
    fontWeight: 600
    lineHeight: 1
  headline:
    fontFamily: "SF Pro, system-ui"
    fontSize: "28pt"
    fontWeight: 600
    lineHeight: 1.15
  title:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17pt"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "15pt"
    fontWeight: 500
    lineHeight: 1.35
  label:
    fontFamily: "SF Pro Rounded, SF Pro, system-ui"
    fontSize: "11pt"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.2pt"
rounded:
  control: "14pt"
  button: "16pt"
  card: "22pt"
  hero: "34pt"
spacing:
  xs: "4pt"
  sm: "8pt"
  md: "16pt"
  lg: "24pt"
  xl: "32pt"
components:
  button-primary:
    backgroundColor: "{colors.garage-gold}"
    textColor: "{colors.garage-emerald-deep}"
    typography: "{typography.title}"
    rounded: "{rounded.button}"
    height: "56pt"
  card-raised:
    backgroundColor: "{colors.garage-surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.md}"
  control-inset:
    backgroundColor: "{colors.garage-emerald-glass}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.control}"
    height: "44pt"
---

# Design System: LIFE IN SYNC

## 1. Overview

**Creative North Star: "The Focused Instrument"**

LIFE IN SYNC should feel like a set of trusted native instruments, each tuned for a specific life domain. The shared system is calm and familiar; flagship module surfaces add tactile depth and atmosphere without inventing unfamiliar interaction laws.

Garage is the clearest expression of the system: dark emerald depth, restrained warm-gold emphasis, practical copy, and a compact action hierarchy. It explicitly rejects generic AI visuals, fake dashboards, decorative theatrics, and settings-heavy practice screens.

**Key Characteristics:**
- SwiftUI-first, Apple-native interaction.
- Strong hierarchy with few competing surfaces.
- Dark layered flagship atmosphere with restrained accent usage.
- One obvious primary action per execution screen.
- Motion and haptics communicate state, never decoration.

## 2. Colors

The Garage palette combines deep practice-green surfaces with rare warm-gold emphasis and highly readable white or mint text.

### Primary
- **Practice Gold** (`#FABF2E`): Dominant action, active timing marker, and selected practice state.
- **System Garage Accent** (`#FDE047`): Shared Garage cue color used sparingly for module-level emphasis.

### Secondary
- **Deep Emerald** (`#031A12`): Flagship background depth and dark primary-button text.
- **Practice Emerald** (`#175938`): Atmospheric emphasis and active practice energy.

### Neutral
- **Turf Base** (`#2D7A3E`): Shared Garage background.
- **Turf Surface** (`#236331`): Raised and inset Garage surfaces.
- **Analysis Canvas** (`#0D141B`): Dark review and data canvas.
- **Primary White** (`#FFFFFF`): Primary text.
- **Mint Support** (`#A8D6B3`): Secondary text and quiet supporting cues.

### Named Rules

**The Rare Gold Rule.** Gold marks the primary action, current selection, or timing-critical cue. It does not fill large inactive surfaces.

**The Readability Rule.** Never trade text contrast for atmospheric green.

## 3. Typography

**Display Font:** SF Pro Rounded, with SF Pro Display fallback  
**Body Font:** SF Pro, system-ui  
**Label Font:** SF Pro Rounded or SF Pro

**Character:** Native, compact, and practical. Rounded typography is reserved for tempo values, timers, and selected Garage accents; standard SF Pro carries navigation, body copy, and controls.

### Hierarchy
- **Display** (semibold, 58pt, 1.0): Hero values such as BPM and timers.
- **Headline** (semibold, 28pt, 1.15): Full-screen section titles and Control Room.
- **Title** (semibold, 17pt, 1.2): Navigation titles and prominent controls.
- **Body** (medium, 15pt, 1.35): Practical instructions and settings values.
- **Label** (bold, 11pt, 1.2pt tracking): Rare state or category labels.

### Named Rules

**The Practical Copy Rule.** Labels tell the golfer what the control does. Avoid gimmicky naming and repeated uppercase eyebrows.

## 4. Elevation

The system uses a hybrid of tonal layering, fine borders, and restrained ambient shadows. Flagship surfaces can feel tactile, but shadows should never become ornamental glow.

### Shadow Vocabulary
- **Raised Panel:** Dark shadow at roughly 28% opacity, 10-12pt blur, and 6-8pt downward offset.
- **Active Cue:** Low-opacity gold or module-accent glow limited to the active control or timing marker.
- **Inset Surface:** Darker tonal fill plus a fine light edge; avoid heavy inner-shadow simulation.

### Named Rules

**The Layer Before Glow Rule.** Establish depth through fill, spacing, and border before adding any glow.

## 5. Components

### Buttons
- **Shape:** Continuous rounded rectangle, typically 16pt radius and 56pt height for primary execution actions.
- **Primary:** Practice Gold with Deep Emerald text; one dominant primary action per screen.
- **Focus / Active:** Native pressed feedback and optional light haptic; never shift surrounding layout.
- **Secondary / Ghost:** Dark or transparent surface with white or Mint Support text and a fine border.

### Chips
- **Style:** Compact, low-emphasis inset surfaces with clear selected state.
- **State:** Selected uses limited accent color; inactive states remain quiet.

### Cards / Containers
- **Corner Style:** Continuous 14-22pt radius according to hierarchy.
- **Background:** Turf Surface, Emerald Glass, or Analysis Canvas.
- **Shadow Strategy:** Structural ambient shadow only.
- **Border:** Fine white or mint-tinted border at low opacity.
- **Internal Padding:** Usually 14-20pt.

### Inputs / Fields
- **Style:** Native controls adapted to dark surfaces with clear labels and readable values.
- **Focus:** Accent tint or border shift, not decorative glow.
- **Error / Disabled:** Explicit semantic state plus reduced emphasis; never rely on color alone.

### Navigation
- Dashboard owns the root shell. Modules own their internal flows.
- Use standard back behavior and compact native headers.
- Keep secondary actions visually quieter than the page title and primary task.

### Practice Instrument

Live Garage tools use the hierarchy `identity -> primary value or cue -> rhythm/timer/tracker -> primary action`. Settings and sound libraries belong behind a clear secondary entry, not inside the execution surface.

## 6. Do's and Don'ts

### Do:
- **Do** make one meaningful action visually dominant.
- **Do** use native SwiftUI controls, semantics, and at least 44pt touch targets.
- **Do** preserve module boundaries and Dashboard-owned root navigation.
- **Do** use spacing, typography, and tonal layering before decorative effects.
- **Do** respect Reduce Motion and keep state transitions near 150-300ms.

### Don't:
- **Don't** use generic demo-app styling or default ugly `Form` screens on flagship surfaces.
- **Don't** use generic AI-app visuals, fake dashboard complexity, or autonomous-agent behavior.
- **Don't** build cluttered card stacks or card-inside-card layouts.
- **Don't** use gimmicky labels, novelty sounds, playful or corny treatments, noisy gradients, excessive glow, or decorative theatrics.
- **Don't** expose database-facing configuration inside player-facing practice flows.
- **Don't** add cloud-first, social, collaborative, subscription, or account-driven patterns without explicit approval.
