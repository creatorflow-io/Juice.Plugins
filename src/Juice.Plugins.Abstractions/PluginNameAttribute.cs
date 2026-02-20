namespace Juice.Plugins
{
    /// <summary>
    /// Declares a human-readable name for a plugin assembly.
    /// Apply at assembly level: <c>[assembly: PluginName("My Plugin")]</c>
    /// <para>
    /// When present and non-empty, this value is used as <see cref="IPlugin.Name"/>.
    /// When absent, null, or whitespace, <see cref="IPlugin.Name"/> falls back to the
    /// containing directory name of the plugin DLL.
    /// </para>
    /// </summary>
    [AttributeUsage(AttributeTargets.Assembly, AllowMultiple = false, Inherited = false)]
    public sealed class PluginNameAttribute : Attribute
    {
        /// <summary>
        /// Gets the declared plugin name.
        /// </summary>
        public string Name { get; }

        /// <summary>
        /// Initializes a new instance of <see cref="PluginNameAttribute"/>.
        /// </summary>
        /// <param name="name">The human-readable name of the plugin.</param>
        public PluginNameAttribute(string name)
        {
            Name = name;
        }
    }
}
