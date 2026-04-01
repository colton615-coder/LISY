# Command Center - Personal Dashboard PRD

> **Deployment Status**: ✅ Ready for Production - All mock and sample data has been cleared. The app starts with a clean slate and includes a data reset feature in Settings for users who want to start fresh.

A comprehensive personal dashboard application that integrates habit tracking, financial management, task management, workout planning, AI coaching (Knox), shopping lists, calendar events, and golf swing analysis. The app features a neumorphic dark theme with glassmorphic elements, providing a modern and cohesive user experience across all modules.

**Experience Qualities**:
1. **Satisfying** - Each tap provides immediate visual feedback with icons filling up, creating a dopamine-rewarding experience
2. **Motivating** - Visual progress bars and celebration animations encourage users to complete their daily goals
3. **Simple** - No complex menus or settings—just set a goal, tap throughout the day, and watch progress
4. **Personalized** - Customizable theme options (light, dark, system) allow users to tailor the app's appearance to their preferences

**Complexity Level**: Light Application (focused feature set with visual feedback, daily state tracking, and cross-module completion analytics)
  - Habit tracking tool with visual icon-based progress, celebration animations, daily completion history, and a global completion tracking system for analytics across all modules

## Essential Features

### Loading Screen with Daily Affirmations
- **Functionality**: Display an animated loading screen with inspirational quotes or Bible verses while the app initializes, using AI to generate fresh content
- **Purpose**: Create positive user experience on app launch while masking load time, set motivational tone for the session
- **Trigger**: User opens or refreshes the app
- **Progression**: App loads → Loading screen appears with animated background → AI fetches daily affirmation → Quote/verse animates in with elegant typography → App content loads in background → Smooth fade transition to main interface
- **Success criteria**: Loading screen displays within 100ms, affirmation appears smoothly and remains visible for ~4 seconds to allow reading, transitions feel seamless, fallback quotes available if AI fails

### Visual Progress Tracking
- **Functionality**: Display a grid of icon representations (glasses for water, checkmarks for habits, etc.) that fill/highlight as user directly taps individual icons to log progress toward daily goal
- **Purpose**: Create satisfying visual feedback that motivates completion through seeing progress accumulate with direct icon interaction
- **Trigger**: User sets daily goal (e.g., "8 glasses of water")
- **Progression**: User opens app → Sees grid of 8 empty glass icons → Taps individual icons throughout day → Each tapped icon fills with animated color transition → Final icon triggers celebration animation → Completion logged to history
- **Success criteria**: Icons animate smoothly on tap (< 200ms), celebration fires on final completion, daily progress persists, clicking filled icons allows adjusting progress backwards

### Goal Setting
- **Functionality**: Simple interface to set habit name, choose icon type, and set daily target number
- **Purpose**: Allow users to customize tracking for different habit types (water, steps, pages read, etc.)
- **Trigger**: User taps "Add Habit" or edits existing habit
- **Progression**: Tap add habit → Enter habit name → Select icon type from preset options → Set target number (1-20) → Habit appears in list
- **Success criteria**: Changes save immediately, icon selection is intuitive, reasonable numeric limits prevent errors

### Celebration Animation
- **Functionality**: Confetti or particle animation with sound/haptic feedback when daily goal is completed
- **Purpose**: Provide dopamine reward for completing goal, reinforcing positive behavior
- **Trigger**: User completes final increment of daily goal by tapping the last empty icon
- **Progression**: User taps final empty icon → Icon fills → Screen-wide celebration animation plays → Success message appears → Completion recorded with timestamp
- **Success criteria**: Animation plays within 100ms of completion, feels rewarding without being excessive (2-3 seconds), doesn't block continued interaction

### History & Streaks
- **Functionality**: Calendar view showing which days goals were completed, current streak counter, completion analytics across all modules
- **Purpose**: Provide long-term motivation through streak building, visual history, and data-driven insights into completion patterns
- **Trigger**: User views history tab, sees streak badge on main screen, or accesses analytics dashboard
- **Progression**: User completes daily goal → Completion logged with date → Calendar marks day as complete → Streak counter increments if consecutive → Completion stats update → User can view past days and patterns across modules
- **Success criteria**: Streak calculates correctly across day boundaries, history persists indefinitely, missed days clearly visible, completion data can be analyzed across all modules

### Global Completion Tracking System
- **Functionality**: Unified system for tracking, separating, and analyzing completed vs. active items across all modules (Habits, Tasks, Workouts, etc.)
- **Purpose**: Provide consistent completion tracking, enable rich analytics, maintain data integrity, and allow cross-module insights
- **Trigger**: Any item completion in any module
- **Progression**: User completes item → Completion timestamp recorded → Item moved to completed list → Stats updated in real-time → Analytics data accumulated → User can filter by completion status and view statistics
- **Success criteria**: All modules use consistent completion tracking, active/completed items properly separated, statistics accurate, completion data persists, filters work correctly, analytics provide actionable insights

### AI Financial Advisor Interview & Budget Generation
- **Functionality**: Multi-step interview process where an AI financial advisor asks comprehensive questions about income, housing, debt, goals, and spending habits, then generates a detailed, personalized budget plan (currently uses Spark LLM, planned migration to Gemini Pro 2.5 for enhanced reasoning)
- **Purpose**: Provide in-depth financial planning through conversational AI guidance, creating optimized budget allocations based on user's complete financial picture
- **Trigger**: User navigates to Finance module → AI Financial Advisor tab
- **Progression**: User starts interview → Answer 5 step questionnaire covering income, housing, debt, goals, and spending habits → AI analyzes complete profile → Generates detailed budget with category allocations → Shows personalized recommendations with reasoning → Provides savings strategy → Offers debt payoff plan (if applicable) → Displays actionable steps
- **Success criteria**: Interview feels conversational and thorough, all financial factors considered, budget totals balance to income, recommendations are specific and practical, AI reasoning is clear and helpful, budget persists for future reference, user can restart process anytime

### AI Provider Integration (Planned)
- **Functionality**: Integrate Google Gemini Pro 2.5 alongside existing Spark LLM (GPT-4o) with intelligent routing, fallback mechanisms, and unified abstraction layer
- **Purpose**: Leverage best AI model for each task, optimize costs, improve reasoning capabilities for complex features, enable multimodal futures
- **Trigger**: Developer configures Gemini API key in settings (owner only)
- **Progression**: Owner adds API key → System validates configuration → AI router automatically selects optimal provider per feature → Usage tracked for cost optimization → Automatic fallback on failures → Analytics show provider performance
- **Success criteria**: Seamless provider switching, <3s response times, >99% uptime with fallback, secure key storage, no user-facing errors, cost tracking accurate, documentation complete

### Theme Personalization
- **Functionality**: Toggle between light, dark, and system-preferred themes with persistent storage of user preference
- **Purpose**: Provide visual customization that adapts to user environment and preference, enhancing comfort and accessibility
- **Trigger**: User clicks theme toggle button (top-right corner or in navigation drawer)
- **Progression**: User opens theme menu → Selects light, dark, or system theme → Interface transitions smoothly to selected theme → Preference saved automatically → Theme persists across sessions
- **Success criteria**: Theme changes apply instantly with smooth transitions, user preference persists between sessions, system theme automatically adapts to OS preference changes, all UI elements properly support both themes with correct contrast ratios

### Shopping List Module
- **Functionality**: Minimalist shopping list manager with add, edit, delete, and check/uncheck capabilities—just like pen and paper, but with beautiful digital polish
- **Purpose**: Provide a distraction-free shopping list experience that feels natural and effortless, like writing on a notepad
- **Trigger**: User navigates to Shopping module from navigation drawer
- **Progression**: User opens Shopping → Sees clean neumorphic notepad interface → Types item name and clicks Add → Item appears in list with checkbox → User checks off items while shopping → Checked items move to bottom with strikethrough → User can inline-edit any item name → User can delete items → Simple counter shows active vs completed items
- **Success criteria**: Interface feels like a physical notepad, add/edit/delete operations are instant with smooth animations, items persist between sessions using useKV, inline editing feels natural, completed items remain visible but visually de-emphasized, all interactions are polished with subtle hover states and satisfying micro-interactions

### Golf Swing Analyzer Module
- **Functionality**: Professional AI-powered golf swing analysis using pose estimation to extract 3D landmarks, compute critical metrics (spine angle, hip rotation, head movement, swing plane, tempo, weight transfer), and generate personalized feedback with drill recommendations. Supports large video files up to 500MB for high-quality analysis.
- **Purpose**: Provide golfers with instant, professional-grade swing analysis without expensive coaching sessions, enabling data-driven improvement through actionable insights
- **Trigger**: User navigates to Golf Swing module (formerly Vault) from navigation drawer
- **Progression**: User uploads swing video (MP4, MOV, AVI, etc. up to 500MB) → Video processes with real-time progress display (uploading → extracting frames → pose estimation → analyzing mechanics → generating AI insights) → Large files (>200MB) show extended processing notification → Completed analysis displays with video playback, detailed metrics dashboard, strengths/improvements breakdown, AI-generated insights, and personalized practice drills → User can upload multiple swings and compare progress over time → Historical analyses persist in sidebar for easy access
- **Success criteria**: Video upload accepts common formats under 500MB with informative feedback for large files, processing completes with accurate progress feedback, pose estimation detects key body landmarks reliably, metrics calculations are accurate and meaningful, AI feedback is specific and actionable, drill recommendations target actual weaknesses, interface is intuitive for non-technical users, all data persists between sessions, video playback is smooth, comparison view shows improvement trends

## Edge Case Handling
- **Empty States**: Show welcoming prompt "Start your first habit!" with animated icon when no habits exist; "Upload Your First Swing" for golf analyzer
- **Goal Already Complete**: Show success state when daily goal is reached; icons remain clickable to adjust progress
- **Date Boundaries**: Progress resets at midnight local time; completed days logged to history
- **Multiple Habits**: Support tracking multiple different habits simultaneously with separate progress for each
- **Accidental Taps**: Clicking filled icons adjusts progress backwards to that point, allowing easy corrections
- **Long Streaks**: Special milestone celebrations at 7, 30, 100 days with different animations
- **Data Loss Prevention**: Confirm before deleting habits; show toast with undo option
- **Theme Transitions**: Smooth color transitions when switching themes; no jarring flashes
- **System Theme Changes**: Automatically adapt when user changes OS theme preference (when system theme is selected)
- **Video Upload Errors**: Validate file type and size before processing, show clear error messages for unsupported formats or files exceeding 500MB limit with guidance to compress video
- **Large Video Files**: Files over 200MB show informative notification about extended processing time, graceful handling of memory constraints
- **Processing Failures**: Graceful error handling with retry option, error state persists in analysis list
- **Incomplete Analysis**: Partial results saved if analysis fails mid-process, user can delete and retry
- **No Video Selected**: File input validates selection before starting upload process
- **Browser Compatibility**: Video playback fallbacks for unsupported codecs, WebGL requirements checked for pose estimation

## Design Direction
The interface should evoke a premium, futuristic tech aesthetic inspired by Tesla Cybertruck's UI and high-end automotive dashboards—sophisticated, minimalist, and cutting-edge. The neumorphic (soft-UI) approach with dark backgrounds, subtle depth through shadows, and glowing cyan accents creates a tactile, three-dimensional interface that feels both tangible and futuristic. Every element should feel precisely crafted with purposeful micro-interactions, smooth physics-based animations, and attention to detail that reinforces premium quality.

## Color Selection
**Neumorphic Dark Palette with Electric Cyan Glow**: The design uses a dark neumorphic style with charcoal gray surfaces that create soft, raised or inset effects through dual-shadow techniques (light shadow from top-left, dark shadow from bottom-right). Vibrant electric cyan serves as the primary accent, providing a high-tech glow effect that stands out beautifully against dark backgrounds.

**Dark Neumorphic Theme:**
- **Primary Color**: Electric Cyan (oklch 0.68 0.19 211) - High-tech glow for active buttons, primary actions, progress rings, and interactive highlights; used with box-shadow glow effects
- **Secondary Colors**: 
  - Card Surface (oklch 0.26 0.01 240) - Raised neumorphic cards with dual shadow
  - Main Background (oklch 0.22 0.01 240) - Deep charcoal base
  - Elevated Elements (oklch 0.30 0.015 240) - Borders and lighter surfaces
- **Accent Color**: Electric Cyan with glow - Creates depth through 0 0 20px oklch(0.68 0.19 211 / 0.3) shadows for glowing buttons and active states
- **Foreground/Background Pairings**:
  - Background (Deep Charcoal oklch 0.22 0.01 240): Light Text (oklch 0.95 0.005 240) - Ratio 16.8:1 ✓
  - Card (Charcoal oklch 0.26 0.01 240): Light Text (oklch 0.95 0.005 240) - Ratio 14.2:1 ✓
  - Primary (Cyan oklch 0.68 0.19 211): White text (oklch 0.98 0.005 240) - Ratio 5.1:1 ✓
  - Secondary (Mid Charcoal oklch 0.30 0.015 240): Light text (oklch 0.90 0.01 240) - Ratio 8.4:1 ✓
  - Muted (Dark Gray oklch 0.28 0.01 240): Muted text (oklch 0.55 0.01 240) - Ratio 4.6:1 ✓

## Font Selection
Typography should convey technical precision and modern elegance through clean sans-serif fonts optimized for digital displays—Outfit for display/headings and Inter for body text, both with excellent legibility on dark backgrounds.

- **Typographic Hierarchy**:
  - H1 (Page Titles): Outfit Bold / 48px mobile, 80px desktop / tight letter spacing (-0.02em) / 1.1 line height / gradient text effect
  - H2 (Section Headers): Outfit SemiBold / 28px / tight (-0.01em) / 1.2
  - H3 (Widget Titles): Inter SemiBold / 14px / uppercase / wide spacing (0.05em) / muted color
  - H4 (Card Headers): Outfit Medium / 20px / normal / 1.3
  - Body (Descriptions): Inter Regular / 16px / normal / 1.5
  - Stats (Large Numbers): Outfit Bold / 64px / tight / 1.0 / tabular-nums / gradient effect
  - Data Labels: Inter Medium / 12px / uppercase / wide (0.08em) / 1.4 / muted color
  - Captions: Inter Regular / 14px / normal / 1.4
  - Metrics: Inter SemiBold / 18px / tabular-nums

## Animations
Animations should feel smooth, polished, and physics-based—like premium automotive interfaces. Transitions use spring-based easing for natural, satisfying motion. The balance is purposeful micro-interactions that delight without distracting, with hover states that respond instantly and state changes that feel tactile through subtle scale and glow effects.

- **Purposeful Meaning**: Spring-based animations communicate premium quality; cyan glow pulses indicate active/processing states; neumorphic depth changes (pressed/raised) provide tactile feedback; smooth fades maintain context during navigation
- **Hierarchy of Movement**: 
  - Primary: Button press depth changes (200ms spring), glow pulse on active elements (3s infinite), circular progress rings with smooth transitions
  - Secondary: Card hover elevation with 4px lift (300ms spring), page transitions with fade (400ms), drawer slide with spring physics
  - Tertiary: Icon color shifts (150ms ease), input focus glow (200ms), micro-scale on tap (100ms)

## Component Selection

- **Components**:
  - **NeumorphicCard**: Primary container with dual-shadow depth effect (raised or inset variants)
  - **Dialog**: Forms and modals with neumorphic styling and backdrop blur
  - **Progress**: Circular rings with cyan glow, linear bars with gradient fill
  - **Badge**: Pill-shaped indicators with subtle inset styling
  - **Tabs**: Segmented control with active state using glowing cyan button
  - **Input**: Inset neumorphic fields with focus glow effect
  - **Button**: Raised neumorphic (default) or glowing cyan (primary) variants with press depth animation
  - **ScrollArea**: Custom thin scrollbar with neumorphic track
  - **IconCircle**: 56px circular container with neumorphic depth, optional cyan glow for active state

- **Customizations**:
  - **Glowing Buttons**: Cyan background with box-shadow glow (0 0 20px cyan/0.4) that intensifies on hover
  - **Neumorphic Surfaces**: Dual-shadow technique (8px 8px 16px dark, -4px -4px 12px light) for raised effect
  - **Metric Display**: Extra-large numbers (64px+) with gradient cyan effect and tabular numerals
  - **Progress Rings**: SVG circular progress with cyan stroke, drop-shadow glow, and smooth transitions
  - **Mode Buttons**: 64px circular neumorphic buttons that transform to glowing cyan when active

- **States**:
  - **Buttons**: Default (raised neumorphic with dual shadow), Hover (slightly elevated, reduced shadow), Active (inset depth with inverted shadow), Glow Variant (cyan background with box-shadow glow)
  - **Cards**: Default (raised neumorphic), Hover (increased elevation with 4px lift, optional glow border), Active (subtle scale 0.98)
  - **Icon Circles**: Default (raised 56px circle), Hover (reduced shadow depth), Glow (cyan background with radial glow)

- **Icon Selection**:
  - Primary Icons: House (dashboard), CheckSquare (habits), CurrencyDollar (finance), ListChecks (tasks), Barbell (workouts), Brain (Knox AI)
  - All icons use Phosphor Icons with 'regular' weight by default, 'fill' weight for active states
  - Consistent 20-24px sizing for most contexts, 28px+ for primary navigation

- **Spacing**: 8-based scale with generous breathing room (16px, 24px, 32px, 48px) between cards; internal card padding of 24px-32px; icon circles with 12-16px spacing; min touch targets of 56px (icon circles) and 48px (buttons)

- **Mobile**: 
  - Full-width neumorphic cards with 16px horizontal margins
  - Large touch targets (56px+ icon circles, 48px+ buttons)
  - Bottom-anchored navigation with neumorphic FAB (80px)
  - Drawer navigation slides from left with backdrop blur
  - Reduced card padding (16px) and font sizes on mobile
  - Single column grid layout below 768px

## Accessibility & UX Improvements

### Chart Accessibility
All data visualizations include text-based alternatives via the `AccessibleChart` component:
- **Data Table Toggle**: Users can switch between visual charts and accessible data tables
- **Screen Reader Support**: Proper ARIA labels and semantic markup
- **Keyboard Navigation**: All chart controls are fully keyboard accessible
- **Format Options**: Custom column formatters for readable data display
- **Implementation**: Finance module's spending breakdown chart demonstrates the pattern

### Component Library Consolidation
Standardized card components to single source of truth:
- **Primary Component**: `NeumorphicCard` for all card-based UI elements
- **Features**: Hover effects, pressed states, inset variants, glow borders, optional animations
- **Deprecated**: Old `Card.tsx` component replaced with NeumorphicCard
- **Consistency**: Uniform neumorphic styling across all modules
- **Documentation**: See `COMPONENT_CONSOLIDATION.md` for migration guide

## AI Integration

### Dual Provider Architecture
The app supports two AI providers with intelligent routing and automatic fallback:

- **Spark LLM (GPT-4o)**: Built-in provider, no configuration needed, excellent for JSON and quick responses
- **Google Gemini 2.5**: Optional provider requiring API key, cost-effective for long context and complex reasoning

### AI Provider Router
- **Functionality**: Unified interface that routes AI requests to optimal provider based on task and user preferences
- **Purpose**: Maximize reliability through automatic fallback while optimizing for cost and performance
- **Features**:
  - Automatic provider selection based on task complexity
  - Seamless fallback if primary provider fails
  - User-configurable preferences (Automatic, Spark, or Gemini)
  - Usage tracking and cost monitoring
  - Support for both text and JSON generation

### Current AI Features
1. **Daily Affirmations** - Generated motivational quotes on app load (Spark LLM)
2. **AI Financial Advisor** - Multi-step interview and personalized budget generation (Can use either provider)
3. **Habit Suggestions** - AI-powered recommendations based on existing habits (Gemini recommended)
4. **Spending Analysis** - Pattern detection and financial insights (Gemini recommended)
5. **Workout Generation** - Custom workout plans based on fitness level and goals (Either provider)

### Settings & Configuration
- **Gemini API Key Management**: Secure storage in Spark KV, owner-only access
- **Connection Testing**: Verify API key validity before use
- **Provider Selection**: Choose default provider or let system auto-route
- **Usage Statistics**: Track requests, tokens, and costs per provider
- **AI Provider Badges**: Visual indicators showing which AI powered each feature

### Implementation Details
- **Location**: `/src/lib/ai/` and `/src/lib/gemini/`
- **Key Files**:
  - `ai/provider.ts` - Main AI router with fallback logic
  - `ai/usage-tracker.ts` - Cost and usage monitoring
  - `gemini/client.ts` - Gemini API wrapper
  - `ai/examples.ts` - Pre-built helper functions
- **Components**: AIBadge for provider indication, AccessibleChart for data viz
- **Module**: Settings page for configuration (owner-only)

### Security Considerations
- API keys stored encrypted in Spark KV store
- Never exposed in client code or logs
- Owner-only access to configuration
- Secure key masking in UI
- Error messages don't leak sensitive info
