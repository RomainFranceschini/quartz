# 0.3.0

- Distinguish between state variables and parameters
- Mask WIP priority queues under `-Dexperimental` compile-time flag
- Add a convenient `#after_initialize` method for initializing models
- Improved `Duration` API
- Fixed bug computing initial internal event with initial elapsed times
- Fixed arithmetic error initializing durations with `Duration.from(0.0)`

Improved documentation in the wiki.

# 0.2.0

- **(breaking-change)** State refactor ([#15](https://github.com/RomainFranceschini/quartz/pull/15))
  - `state_var : Type = value` replaced by `state { var : Type = value }`
  - State variables are no longer part of the model, the model now has a reference to its companion class `State`.

# 0.1.0

- First version
