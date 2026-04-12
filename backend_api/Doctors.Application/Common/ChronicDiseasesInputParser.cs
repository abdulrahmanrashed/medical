namespace Doctors.Application.Common;

/// <summary>Parses free-text chronic conditions from registration / profile into a bounded list.</summary>
public static class ChronicDiseasesInputParser
{
    public static List<string> FromFreeText(string? s)
    {
        if (string.IsNullOrWhiteSpace(s))
            return new List<string>();
        return s
            .Split(new[] { ',', ';', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(x => x.Trim())
            .Where(x => x.Length > 0)
            .Take(50)
            .ToList();
    }
}
