using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

/// <summary>
/// Patient profile and credentials. Primary key <see cref="Id"/> is a stable UUID (patient_id).
/// </summary>
public class Patient
{
    public Guid Id { get; set; }

    /// <summary>Normalized digits-only phone; unique; used for login.</summary>
    public string PhoneNumber { get; set; } = string.Empty;

    public string? Email { get; set; }

    /// <summary>ASP.NET Identity-compatible password hash; null while <see cref="RegistrationStatus"/> is Draft.</summary>
    public string? PasswordHash { get; set; }

    public string FullName { get; set; } = string.Empty;

    public bool InsuranceStatus { get; set; }

    public string? InsuranceDetails { get; set; }

    public string? ChronicDiseases { get; set; }

    /// <summary>DRAFT = created by reception with phone/name only; COMPLETED = patient finished app registration.</summary>
    public PatientRegistrationStatus RegistrationStatus { get; set; } = PatientRegistrationStatus.Draft;

    /// <summary>Linked Identity user after registration is completed; used for JWT and notifications.</summary>
    public string? UserId { get; set; }

    public DateTime? DateOfBirth { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }

    public ICollection<PatientClinic> PatientClinics { get; set; } = new List<PatientClinic>();
    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
    public ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();
}
