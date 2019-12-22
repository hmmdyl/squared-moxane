module moxane.physics.commands;

package enum PhysicsCommands
{
	nop,
	colliderCreate,
	colliderDestroy,
	colliderUpdateFields,
	rigidBodyCreate,
	rigidBodyDestroy,
	rigidBodyUpdateFields
}

package struct PhysicsCommand
{
	PhysicsCommands type;
	Object target;
	
	this(PhysicsCommands type, Object target)
	{
		this.type = type;
		this.target = target;
	}
}