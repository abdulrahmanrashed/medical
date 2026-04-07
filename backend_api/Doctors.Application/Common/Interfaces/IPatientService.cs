using Doctors.Application.DTOs.Patients;

namespace Doctors.Application.Common.Interfaces;

public interface IPatientService
{
    Task<PatientDto> GetMyProfileAsync(CancellationToken cancellationToken = default);
    Task<PatientDto> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PatientDto>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<PatientDto> LinkToClinicAsync(LinkPatientClinicDto dto, CancellationToken cancellationToken = default);
    Task<PatientDto> CreateDraftAsync(CreateDraftPatientDto dto, CancellationToken cancellationToken = default);

    /// <summary>Scenario A: find by normalized phone or create DRAFT (name + phone). Never creates a second row for the same phone.</summary>
    Task<PatientDto> FindOrCreateDraftByPhoneAsync(
        ReceptionFindOrCreatePatientDto dto,
        CancellationToken cancellationToken = default);

    /// <summary>Reception/admin: resolve patient by phone for booking UI (no create).</summary>
    Task<PatientDto?> LookupByPhoneForReceptionAsync(string phone, CancellationToken cancellationToken = default);

    /// <summary>Scenario B follow-up + settings: update the current patient by stable Id; phone change syncs Identity UserName.</summary>
    Task<PatientDto> UpdateMyProfileAsync(UpdatePatientProfileDto dto, CancellationToken cancellationToken = default);

    /// <summary>Public (anonymous): phone lookup for app registration — draft rows return fields to prefill; completed means use login.</summary>
    Task<PatientRegistrationLookupResponseDto> LookupForAppRegistrationAsync(
        string phone,
        CancellationToken cancellationToken = default);
}
