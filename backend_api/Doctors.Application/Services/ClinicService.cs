using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Clinics;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class ClinicService : IClinicService
{
    private readonly IRepository<Clinic> _clinics;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IClinicAdminProvisioner _clinicAdminProvisioner;

    public ClinicService(
        IRepository<Clinic> clinics,
        IUnitOfWork unitOfWork,
        IMapper mapper,
        IClinicAdminProvisioner clinicAdminProvisioner)
    {
        _clinics = clinics;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _clinicAdminProvisioner = clinicAdminProvisioner;
    }

    public async Task<IReadOnlyList<ClinicDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var list = await _clinics.Query()
            .Include(c => c.Doctors)
            .OrderBy(c => c.Name)
            .ToListAsync(cancellationToken);
        return _mapper.Map<IReadOnlyList<ClinicDto>>(list);
    }

    public async Task<ClinicDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.Query()
            .Include(c => c.Doctors)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        return _mapper.Map<ClinicDto>(clinic);
    }

    public async Task<ClinicDto> CreateAsync(CreateClinicDto dto, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var entity = new Clinic
        {
            Name = dto.Name,
            Address = dto.Address,
            Phone = dto.Phone,
            Email = dto.Email,
            PaymentStatus = ClinicPaymentStatus.Unpaid,
            SubscriptionStartDate = now,
            CreatedAtUtc = now
        };
        await _clinics.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        await _clinicAdminProvisioner.CreateAndLinkClinicAdminAsync(
            entity.Id,
            dto.ClinicAdminEmail.Trim(),
            dto.ClinicAdminPassword,
            dto.ClinicAdminFirstName.Trim(),
            dto.ClinicAdminLastName.Trim(),
            cancellationToken);

        return await GetByIdAsync(entity.Id, cancellationToken);
    }

    public async Task<ClinicDto> SetPaymentStatusAsync(int id, ClinicPaymentStatus status, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.GetByIdAsync(id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        clinic.PaymentStatus = status;
        clinic.UpdatedAtUtc = DateTime.UtcNow;
        if (status == ClinicPaymentStatus.Paid)
        {
            clinic.LastPaymentDate = DateTime.UtcNow;
            clinic.SubscriptionOverdueNotifiedAtUtc = null;
        }
        _clinics.Update(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<ClinicDto> UpdateAsync(int id, UpdateClinicDto dto, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.GetByIdAsync(id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        clinic.Name = dto.Name;
        clinic.Address = dto.Address;
        clinic.Phone = dto.Phone;
        clinic.Email = dto.Email;
        clinic.UpdatedAtUtc = DateTime.UtcNow;
        _clinics.Update(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.Query()
            .Include(c => c.Doctors)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        if (clinic.Doctors.Count > 0)
            throw new BadRequestAppException("Cannot delete a clinic that still has doctors assigned.");
        _clinics.Remove(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }
}
