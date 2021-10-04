## `Roles`



Library for managing addresses assigned to a Role.


### `add(struct Roles.Role role, address account)` (internal)



Give an account access to this role.

### `remove(struct Roles.Role role, address account)` (internal)



Remove an account's access to this role.

### `has(struct Roles.Role role, address account) → bool` (internal)



Check if an account has this role.




### `Role`


mapping(address => bool) bearer



