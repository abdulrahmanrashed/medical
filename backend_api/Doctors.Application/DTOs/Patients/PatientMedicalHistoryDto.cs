using Doctors.Application.DTOs.Appointments;
using Doctors.Application.DTOs.MedicalFiles;

namespace Doctors.Application.DTOs.Patients;

public class PatientMedicalHistoryDto
{
    public string? CurrentDiagnosis { get; set; }
    public string? CurrentClinicalNotes { get; set; }
    public DateTime? LatestMedicalRecordAtUtc { get; set; }

    /// <summary>Most recent non-empty requested-tests text from the patient&apos;s appointments.</summary>
    public string? RequestedTests { get; set; }

    public IReadOnlyList<AppointmentPrescriptionDto> ActiveAppointmentPrescriptions { get; set; } =
        Array.Empty<AppointmentPrescriptionDto>();

    public IReadOnlyList<MedicalFileDto> MedicalFiles { get; set; } = Array.Empty<MedicalFileDto>();
}
