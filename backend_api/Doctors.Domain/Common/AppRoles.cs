namespace Doctors.Domain.Common;

public static class AppRoles
{
    public const string Admin = "Admin";
    public const string ClinicAdmin = "ClinicAdmin";
    public const string Doctor = "Doctor";
    public const string Reception = "Reception";
    public const string Patient = "Patient";

    public static IReadOnlyList<string> All { get; } = [Admin, ClinicAdmin, Doctor, Reception, Patient];
}
