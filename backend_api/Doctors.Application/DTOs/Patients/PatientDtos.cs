using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.Patients;

public class PatientDto
{
    public Guid Id { get; set; }
    public string? UserId { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string FullName { get; set; } = string.Empty;
    public bool InsuranceStatus { get; set; }
    public string? InsuranceDetails { get; set; }
    public string? ChronicDiseases { get; set; }
    public PatientRegistrationStatus RegistrationStatus { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public IReadOnlyList<int> ClinicIds { get; set; } = Array.Empty<int>();
}

public class LinkPatientClinicDto
{
    public Guid PatientId { get; set; }
    public int ClinicId { get; set; }
}

/// <summary>Reception/admin creates a DRAFT patient (phone + name) before app registration.</summary>
public class CreateDraftPatientDto
{
    public string Phone { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
}

/// <summary>
/// Scenario A: reception searches by phone; if no row exists, creates DRAFT with this phone and name.
/// If a row already exists (any status), returns it — same <see cref="PatientDto.Id"/> is always the clinical anchor.
/// </summary>
public class ReceptionFindOrCreatePatientDto
{
    public string Phone { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
}

/// <summary>
/// Patient updates profile/contact. Resolved by JWT <c>patient_id</c> — <see cref="PatientDto.Id"/> is never modified.
/// Changing phone updates <see cref="PatientDto.PhoneNumber"/> only; appointments and records keep their existing FK to Id.
/// </summary>
public class UpdatePatientProfileDto
{
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? FullName { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public bool? InsuranceStatus { get; set; }
    public string? InsuranceDetails { get; set; }
    public string? ChronicDiseases { get; set; }
}

/// <summary>Anonymous app registration step: lookup by phone before completing signup.</summary>
public class PhoneRegistrationLookupDto
{
    public string Phone { get; set; } = string.Empty;
}

/// <summary>Safe preview for registration UI. Completed accounts do not expose clinical identifiers.</summary>
public class PatientRegistrationLookupResponseDto
{
    public bool Found { get; set; }
    public PatientRegistrationStatus? RegistrationStatus { get; set; }
    public Guid? PatientId { get; set; }
    public string? FullName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Email { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public bool InsuranceStatus { get; set; }
    public string? InsuranceDetails { get; set; }
    public string? ChronicDiseases { get; set; }
}
