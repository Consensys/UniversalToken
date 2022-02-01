## `AllowlistedRole`



Allowlisted accounts have been forbidden by a AllowlistAdmin to perform certain actions (e.g. participate in a
crowdsale). This role is special in that the only accounts that can add it are AllowlistAdmins (who can also remove
it), and not Allowlisteds themselves.

### `onlyNotAllowlisted(address token)`






### `isAllowlisted(address token, address account) → bool` (public)





### `addAllowlisted(address token, address account)` (public)





### `removeAllowlisted(address token, address account)` (public)





### `_addAllowlisted(address token, address account)` (internal)





### `_removeAllowlisted(address token, address account)` (internal)






### `AllowlistedAdded(address token, address account)`





### `AllowlistedRemoved(address token, address account)`







