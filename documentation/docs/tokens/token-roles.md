## Token roles

Each token deployment has an access control mechanism that allows the creation of roles. Addresses can be assigned and de-assigned to roles. Roles can be used to limit access to specific functions. All token deployments come with four default roles, they are:

1. [Minter](#minter)
2. [Owner](#owner)
3. [Manager](#manager)
4. [Controller](#controller)

You can add an address to any role by using the `_addRole(address, bytes32)`.

### Minter

A minter is allowed to mint tokens using the `mint` function. By default, the owner is a minter. 

There can be multiple minters, and minters can add and remove other minters. 

A function can check if the caller is a minter using the `onlyMinter` function modifier.

### Owner

An owner allows an address to perform administrative actions on a token. 

While there can only be one address marked as owner, an owner can transfer their ownership to another address. An owner can also revoke their ownership entirely, which means no address can perform administrative actions and there is no owner. 

The owner can add and remove any role from any address. By default, an owner is granted all other default roles (minter, manager, controller). When ownership is transferred, access to these roles are transferred as well. 

A function can check if a caller is an owner by using the `onlyOwner` function modifier.

### Manager

A manager is responsible for registering, removing, enabling, or disabling extensions.

There is only one manager, and a manager can transfer their role to a different address. By default, the contract owner is also granted the manager role. 

If an ownership transfer occurs, and the manager is also the initial owner before the transfer, then the manager role is also transferred. However, if an ownership transfer occurs and the manager is not the initial owner before transfer, the manager role remains unchanged. 

A function can check if the caller is manager by using the `onlyManager` function modifier.

### Controller

A controller allows an address to perform controlled transfers, only if the token has the controllable feature enabled. If this feature is not enabled, then this role does nothing. 

Multiple addresses can be given the controller role and controllers can add/remove other controllers. 

A function can check if a caller is a controller by using the `onlyController` function modifier.