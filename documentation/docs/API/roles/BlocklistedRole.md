## `BlocklistedRole`



Blocklisted accounts have been forbidden by a BlocklistAdmin to perform certain actions (e.g. participate in a
crowdsale). This role is special in that the only accounts that can add it are BlocklistAdmins (who can also remove
it), and not Blocklisteds themselves.

### `onlyNotBlocklisted(address token)`






### `isBlocklisted(address token, address account) → bool` (public)





### `addBlocklisted(address token, address account)` (public)





### `removeBlocklisted(address token, address account)` (public)





### `_addBlocklisted(address token, address account)` (internal)





### `_removeBlocklisted(address token, address account)` (internal)






### `BlocklistedAdded(address token, address account)`





### `BlocklistedRemoved(address token, address account)`







