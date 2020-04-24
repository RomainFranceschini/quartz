# 0.2.0

- **(breaking-change)** State refactor ([#15](https://github.com/RomainFranceschini/quartz/pull/15))
  - `state_var : Type = value` replaced by `state { var : Type = value }`
  - State variables are no longer part of the model, the model now has a reference to its companion class `State`.

# 0.1.0

- First version
