namespace Doctors.Application.DTOs.Appointments;

public class AppointmentPrescriptionDto
{
    public int Id { get; set; }
    public int AppointmentId { get; set; }
    public string MedicationName { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public int TimesPerDay { get; set; }
    public DateTime StartDateUtc { get; set; }
    public DateTime? EndDateUtc { get; set; }
}

public class ReplaceAppointmentPrescriptionsDto
{
    public List<AppointmentPrescriptionLineInputDto> Lines { get; set; } = new();
}

public class AppointmentPrescriptionLineInputDto
{
    public string MedicationName { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public int TimesPerDay { get; set; } = 1;
    public DateTime StartDateUtc { get; set; }
    public DateTime? EndDateUtc { get; set; }
}
