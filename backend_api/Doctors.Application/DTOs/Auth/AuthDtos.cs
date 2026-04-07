namespace Doctors.Application.DTOs.Auth;

public class LoginRequestDto
{
    /// <summary>Used for staff accounts (email + password).</summary>
    public string? Email { get; set; }

    /// <summary>Used for patients (phone + password). Digits are normalized server-side.</summary>
    public string? Phone { get; set; }

    public string Password { get; set; } = string.Empty;
}

public class RegisterPatientRequestDto
{
    /// <summary>Completes a reception-created draft or creates a new completed patient when no draft exists.</summary>
    public string Phone { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public bool InsuranceStatus { get; set; }
    public string? InsuranceDetails { get; set; }
    public string? ChronicDiseases { get; set; }
}

public class RegisterDoctorRequestDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public string Specialization { get; set; } = string.Empty;
    public string? LicenseNumber { get; set; }
}

public class RegisterReceptionRequestDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public int ClinicId { get; set; }
}

public class AuthResponseDto
{
    public string Token { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string UserId { get; set; } = string.Empty;
    public IReadOnlyList<string> Roles { get; set; } = Array.Empty<string>();
    public int? DoctorId { get; set; }
    public Guid? PatientId { get; set; }
    public int? AssignedClinicId { get; set; }
}
