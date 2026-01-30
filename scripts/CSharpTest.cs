using Godot;
using System;

[GlobalClass]
public partial class CSharpTest : Node
{
	[Export]
	public int CSharpExport { get; set; }
}
