using System.Text.Json;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Doctors.Infrastructure.Persistence;

/// <summary>Maps <see cref="List{T}"/> of chronic conditions to/from nvarchar JSON; supports legacy plain-text rows.</summary>
public static class ChronicDiseasesValueConverter
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    public static ValueConverter<List<string>, string?> Create() =>
        new(
            v => ToDb(v),
            v => FromDb(v));

    public static string? ToDb(List<string>? v)
    {
        if (v is null || v.Count == 0)
            return null;
        return JsonSerializer.Serialize(v, JsonOptions);
    }

    public static List<string> FromDb(string? v)
    {
        if (string.IsNullOrWhiteSpace(v))
            return new List<string>();
        var s = v.Trim();
        if (s.StartsWith('['))
        {
            try
            {
                var list = JsonSerializer.Deserialize<List<string>>(s, JsonOptions);
                if (list is not null)
                    return list;
            }
            catch
            {
                // fall through — treat as legacy free text
            }
        }

        return new List<string> { s };
    }
}
