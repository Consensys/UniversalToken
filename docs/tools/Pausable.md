## `Pausable`



Base contract which allows children to implement an emergency stop mechanism.

### `whenNotPaused(address token)`



Modifier to make a function callable only when the contract is not paused.

### `whenPaused(address token)`



Modifier to make a function callable only when the contract is paused.


### `paused(address token) → bool` (public)





### `pause(address token)` (public)



called by the owner to pause, triggers stopped state

### `unpause(address token)` (public)



called by the owner to unpause, returns to normal state


### `Paused(address token, address account)`





### `Unpaused(address token, address account)`







