namespace Doctors.Domain.Entities;

public class Prescription : BaseEntity
{
    public int MedicalRecordId { get; set; }
    public MedicalRecord MedicalRecord { get; set; } = null!;
    public int DoctorId { get; set; }
    public Doctor Doctor { get; set; } = null!;

    public ICollection<Medication> Medications { get; set; } = new List<Medication>();
}
