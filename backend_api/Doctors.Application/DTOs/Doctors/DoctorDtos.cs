namespace Doctors.Application.DTOs.Doctors;

public class DoctorDto
{
    public int Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public string ClinicName { get; set; } = string.Empty;
    public string Specialization { get; set; } = string.Empty;
    public string? LicenseNumber { get; set; }
    public string? PhoneNumber { get; set; }
    public int YearsOfExperience { get; set; }
    public string? Gender { get; set; }
    public bool IsActive { get; set; } = true;
}

public class SetDoctorActiveDto
{
    public bool IsActive { get; set; }
}
