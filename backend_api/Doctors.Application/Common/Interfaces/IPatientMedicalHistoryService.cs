using Doctors.Application.DTOs.Patients;

namespace Doctors.Application.Common.Interfaces;

public interface IPatientMedicalHistoryService
{
    Task<PatientMedicalHistoryDto> GetMyMedicalHistoryAsync(CancellationToken cancellationToken = default);
}
