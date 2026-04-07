namespace Doctors.Application.Configuration;

public class AppUrlOptions
{
    public const string SectionName = "App";

    /// <summary>
    /// Optional public origin for absolute file URLs (e.g. https://host:5191). Files are served under wwwroot; stored paths are relative (uploads/...).
    /// </summary>
    public string? PublicOrigin { get; set; }
}
