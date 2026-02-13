using Godot;

[GlobalClass]
public abstract partial class AbstractClass : Node
{
	[Export]
	public int ExportVariable { get; set; }
}
