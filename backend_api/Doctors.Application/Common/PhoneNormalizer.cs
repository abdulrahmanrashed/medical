namespace Doctors.Application.Common;

public static class PhoneNormalizer
{
    /// <summary>Strips non-digits for consistent storage, uniqueness, and login.</summary>
    public static string Normalize(string? phone)
    {
        if (string.IsNullOrWhiteSpace(phone))
            return string.Empty;
        var digits = new string(phone.Where(char.IsDigit).ToArray());
        return digits.Length > 0 ? digits : phone.Trim();
    }
}
