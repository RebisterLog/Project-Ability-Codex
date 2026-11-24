# Create a UI element

UI is built with Fusion and split into a **Component** (logic) and a **View** (pure markup).

## Checklist

1. Create `src/client/ui/components/<Widget>/init.luau` for logic: proxy subscriptions, packets, Router navigation, state.
2. Create `src/client/ui/views/<Widget>.luau` for pure Fusion markup — no business logic.
3. Register the widget in `src/client/ui/main.luau`.
4. Add a story under `src/client/ui/stories/` for visual layout testing if the element is complex.
5. Use `src/client/ui/utils/Router` for navigation between screens.
6. For reactive state, subscribe to Proxy paths and call the cleanup function on destroy. See [[Data schemas and Proxy]].

## Rules

- The client only renders; it never decides combat results. See [[Runtime boundaries]].
- Never send trusted state through UI events directly — go through packets and server validation.
- Shared UI tokens and helpers live under `src/client/ui/utils/`.
- Keep view files free of packet/proxy logic so they stay easy to restyle.

## Verification

- Open the UI Labs story and check layout at multiple aspect ratios.
- Confirm every subscription is cleaned up when the screen closes.
- Run `lune run tools/format.luau --fix --src`.

Related: [[Create a service or component]], [[Input and BindService]], [[Data schemas and Proxy]].
