namespace Doctors.Domain.Entities;

public class Doctor : BaseEntity
{
    public string UserId { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;
    public string Specialization { get; set; } = string.Empty;
    public string? LicenseNumber { get; set; }

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
    public ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();
    public ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();
}
