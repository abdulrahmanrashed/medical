namespace Doctors.Domain.Entities;

public class Doctor : BaseEntity
{
    public string UserId { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;
    public string Specialization { get; set; } = string.Empty;
    public string? LicenseNumber { get; set; }

    public string? PhoneNumber { get; set; }
    public int YearsOfExperience { get; set; }
    public string? Gender { get; set; }

    /// <summary>When false, the doctor cannot sign in or receive new patient bookings (soft freeze).</summary>
    public bool IsActive { get; set; } = true;

    public ICollection<DoctorWorkSchedule> WorkSchedules { get; set; } = new List<DoctorWorkSchedule>();
    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
    public ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();
    public ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();
}
