namespace Doctors.Domain.Entities;

public class MedicalRecord : BaseEntity
{
    public Guid PatientId { get; set; }
    public Patient Patient { get; set; } = null!;
    public int DoctorId { get; set; }
    public Doctor Doctor { get; set; } = null!;
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;

    public string? Symptoms { get; set; }
    public string? Diagnosis { get; set; }
    public string? Notes { get; set; }

    public ICollection<Prescription> Prescriptions { get; set; } = new List<Prescription>();
    public ICollection<FileAttachment> Attachments { get; set; } = new List<FileAttachment>();
}
