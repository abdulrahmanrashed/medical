using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class PatientClinicLinkService : IPatientClinicLinkService
{
    private readonly IRepository<PatientClinic> _links;
    private readonly IPatientRepository _patients;
    private readonly IUnitOfWork _unitOfWork;

    public PatientClinicLinkService(
        IRepository<PatientClinic> links,
        IPatientRepository patients,
        IUnitOfWork unitOfWork)
    {
        _links = links;
        _patients = patients;
        _unitOfWork = unitOfWork;
    }

    public async Task EnsurePatientLinkedToClinicAsync(Guid patientId, int clinicId, CancellationToken cancellationToken = default)
    {
        var exists = await _links.Query()
            .AnyAsync(pc => pc.PatientId == patientId && pc.ClinicId == clinicId, cancellationToken);
        if (exists)
            return;

        _ = await _patients.GetByIdAsync(patientId, cancellationToken)
            ?? throw new NotFoundException($"Patient {patientId} was not found.");

        await _links.AddAsync(new PatientClinic
        {
            PatientId = patientId,
            ClinicId = clinicId,
            LinkedAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow
        }, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }
}
