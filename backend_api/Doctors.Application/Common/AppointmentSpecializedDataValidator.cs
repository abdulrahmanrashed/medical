using System.Text.Json;
using Doctors.Domain.Common;

namespace Doctors.Application.Common;

/// <summary>Validates optional JSON objects for <see cref="AppointmentType"/>-specific fields.</summary>
public static class AppointmentSpecializedDataValidator
{
    private const int MaxJsonLength = 8000;

    /// <returns>Error message or null if valid.</returns>
    public static string? ValidateOrNull(AppointmentType type, string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return null;
        if (json.Length > MaxJsonLength)
            return $"Specialized data must be at most {MaxJsonLength} characters.";

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException)
        {
            return "Specialized data must be valid JSON.";
        }

        if (doc.RootElement.ValueKind != JsonValueKind.Object)
            return "Specialized data must be a JSON object.";

        return type switch
        {
            AppointmentType.PregnancyFollowUp => ValidatePregnancy(doc.RootElement),
            AppointmentType.Diabetes => ValidateDiabetes(doc.RootElement),
            AppointmentType.General or AppointmentType.SpecificDoctor => ValidateEmptyOrUnknown(doc.RootElement),
            _ => null
        };
    }

    private static string? ValidateEmptyOrUnknown(JsonElement root)
    {
        foreach (var _ in root.EnumerateObject())
            return "Specialized data is not used for this appointment type; leave it empty.";
        return null;
    }

    private static readonly HashSet<string> PregnancyKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "weeks",
        "fetalHeartRate"
    };

    private static string? ValidatePregnancy(JsonElement root)
    {
        foreach (var p in root.EnumerateObject())
        {
            if (!PregnancyKeys.Contains(p.Name))
                return $"Unknown field '{p.Name}' for pregnancy follow-up. Allowed: weeks, fetalHeartRate.";
            if (p.Name.Equals("weeks", StringComparison.OrdinalIgnoreCase))
            {
                if (p.Value.ValueKind is not (JsonValueKind.Number or JsonValueKind.Null))
                    return "Field 'weeks' must be a number or null.";
            }
            else if (p.Name.Equals("fetalHeartRate", StringComparison.OrdinalIgnoreCase))
            {
                if (p.Value.ValueKind is not (JsonValueKind.Number or JsonValueKind.Null))
                    return "Field 'fetalHeartRate' must be a number or null.";
            }
        }

        return null;
    }

    private static readonly HashSet<string> DiabetesKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "a1cLevel",
        "weightKg"
    };

    private static string? ValidateDiabetes(JsonElement root)
    {
        foreach (var p in root.EnumerateObject())
        {
            if (!DiabetesKeys.Contains(p.Name))
                return $"Unknown field '{p.Name}' for diabetes visit. Allowed: a1cLevel, weightKg.";
            if (p.Value.ValueKind is not (JsonValueKind.Number or JsonValueKind.Null))
                return $"Field '{p.Name}' must be a number or null.";
        }

        return null;
    }
}
