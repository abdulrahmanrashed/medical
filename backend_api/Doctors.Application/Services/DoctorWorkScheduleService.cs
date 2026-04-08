using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Schedules;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class DoctorWorkScheduleService : IDoctorWorkScheduleService
{
    private readonly IRepository<DoctorWorkSchedule> _schedules;
    private readonly IRepository<Doctor> _doctors;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IUserProfileReader _users;

    public DoctorWorkScheduleService(
        IRepository<DoctorWorkSchedule> schedules,
        IRepository<Doctor> doctors,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IUserProfileReader users)
    {
        _schedules = schedules;
        _doctors = doctors;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _users = users;
    }

    public async Task<IReadOnlyList<DoctorWorkScheduleDto>> GetByClinicAsync(
        int clinicId,
        int? doctorId,
        DateOnly? from,
        DateOnly? to,
        CancellationToken cancellationToken = default)
    {
        EnsureCanAccessClinic(clinicId);

        var query = _schedules.Query()
            .AsNoTracking()
            .Include(s => s.Doctor)
            .Where(s => s.Doctor.ClinicId == clinicId);

        if (doctorId is int did)
            query = query.Where(s => s.DoctorId == did);

        if (from is { } f)
            query = query.Where(s => s.ShiftDate >= f);
        if (to is { } t)
            query = query.Where(s => s.ShiftDate <= t);

        var rows = await query
            .OrderByDescending(s => s.ShiftDate)
            .ThenBy(s => s.DoctorId)
            .ToListAsync(cancellationToken);

        return await MapListAsync(rows, cancellationToken);
    }

    public async Task<IReadOnlyList<DoctorWorkScheduleDto>> BulkUpsertAsync(
        int clinicId,
        BulkDoctorWorkScheduleRequestDto dto,
        CancellationToken cancellationToken = default)
    {
        EnsureCanAccessClinic(clinicId);

        var doctor = await _doctors.Query()
            .FirstOrDefaultAsync(d => d.Id == dto.DoctorId && d.ClinicId == clinicId, cancellationToken)
            ?? throw new NotFoundException($"Doctor {dto.DoctorId} was not found in this clinic.");

        if (!doctor.IsActive)
            throw new BadRequestAppException("Cannot add schedules for a frozen doctor. Unfreeze the doctor first.");

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var dates = ExpandDates(dto, today).ToList();
        if (dates.Count == 0)
            throw new BadRequestAppException("No dates were generated for this request.");

        if (dates.Any(d => d < today))
            throw new BadRequestAppException("Schedules cannot be created or replaced for past dates.");

        ValidateTimesForStatus(dto.Status, dto.StartTime, dto.EndTime);

        var existing = await _schedules.Query()
            .Where(s => s.DoctorId == dto.DoctorId && dates.Contains(s.ShiftDate))
            .ToListAsync(cancellationToken);

        var byDate = existing.ToDictionary(s => s.ShiftDate);

        foreach (var date in dates)
        {
            if (byDate.TryGetValue(date, out var row))
            {
                row.Status = dto.Status;
                row.StartTime = dto.Status == ScheduleShiftStatus.Working ? dto.StartTime : null;
                row.EndTime = dto.Status == ScheduleShiftStatus.Working ? dto.EndTime : null;
                row.Notes = string.IsNullOrWhiteSpace(dto.Notes) ? null : dto.Notes.Trim();
                row.UpdatedAtUtc = DateTime.UtcNow;
                _schedules.Update(row);
            }
            else
            {
                var entity = new DoctorWorkSchedule
                {
                    DoctorId = dto.DoctorId,
                    ShiftDate = date,
                    Status = dto.Status,
                    StartTime = dto.Status == ScheduleShiftStatus.Working ? dto.StartTime : null,
                    EndTime = dto.Status == ScheduleShiftStatus.Working ? dto.EndTime : null,
                    Notes = string.IsNullOrWhiteSpace(dto.Notes) ? null : dto.Notes.Trim(),
                    CreatedAtUtc = DateTime.UtcNow
                };
                await _schedules.AddAsync(entity, cancellationToken);
            }
        }

        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var refreshed = await _schedules.Query()
            .Where(s => s.DoctorId == dto.DoctorId && dates.Contains(s.ShiftDate))
            .Include(s => s.Doctor)
            .OrderBy(s => s.ShiftDate)
            .ToListAsync(cancellationToken);

        return await MapListAsync(refreshed, cancellationToken);
    }

    public async Task<DoctorWorkScheduleDto> UpdateAsync(
        int id,
        UpdateDoctorWorkScheduleDto dto,
        CancellationToken cancellationToken = default)
    {
        var row = await _schedules.Query()
            .Include(s => s.Doctor)
            .FirstOrDefaultAsync(s => s.Id == id, cancellationToken)
            ?? throw new NotFoundException($"Schedule {id} was not found.");

        EnsureCanAccessClinic(row.Doctor.ClinicId);

        if (!row.Doctor.IsActive)
            throw new BadRequestAppException("Cannot update schedules for a frozen doctor.");

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (row.ShiftDate < today)
            throw new BadRequestAppException("Cannot modify a schedule for a past date.");
        if (dto.ShiftDate < today)
            throw new BadRequestAppException("Cannot move a schedule to a past date.");

        ValidateTimesForStatus(dto.Status, dto.StartTime, dto.EndTime);

        // If moving to another date, ensure no duplicate for same doctor+date
        if (dto.ShiftDate != row.ShiftDate)
        {
            var clash = await _schedules.Query()
                .AnyAsync(s => s.DoctorId == row.DoctorId && s.ShiftDate == dto.ShiftDate && s.Id != id, cancellationToken);
            if (clash)
                throw new BadRequestAppException("Another schedule already exists for this doctor on that date.");
        }

        row.ShiftDate = dto.ShiftDate;
        row.Status = dto.Status;
        row.StartTime = dto.Status == ScheduleShiftStatus.Working ? dto.StartTime : null;
        row.EndTime = dto.Status == ScheduleShiftStatus.Working ? dto.EndTime : null;
        row.Notes = string.IsNullOrWhiteSpace(dto.Notes) ? null : dto.Notes.Trim();
        row.UpdatedAtUtc = DateTime.UtcNow;
        _schedules.Update(row);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        row = await _schedules.Query()
            .Include(s => s.Doctor)
            .FirstAsync(s => s.Id == id, cancellationToken);
        return (await MapListAsync(new List<DoctorWorkSchedule> { row }, cancellationToken))[0];
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var row = await _schedules.Query()
            .Include(s => s.Doctor)
            .FirstOrDefaultAsync(s => s.Id == id, cancellationToken)
            ?? throw new NotFoundException($"Schedule {id} was not found.");

        EnsureCanAccessClinic(row.Doctor.ClinicId);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (row.ShiftDate < today)
            throw new BadRequestAppException("Cannot delete a schedule for a past date.");

        _schedules.Remove(row);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private void EnsureCanAccessClinic(int clinicId)
    {
        if (_currentUser.IsInRole(AppRoles.Admin))
            return;

        if (_currentUser.IsInRole(AppRoles.ClinicAdmin))
        {
            var assigned = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
            if (assigned != clinicId)
                throw new ForbiddenException("You can only manage schedules for your own clinic.");
            return;
        }

        throw new ForbiddenException("Only system administrators or clinic administrators can manage doctor schedules.");
    }

    private static void ValidateTimesForStatus(ScheduleShiftStatus status, TimeOnly? start, TimeOnly? end)
    {
        if (status == ScheduleShiftStatus.Working)
        {
            if (start is null || end is null)
                throw new BadRequestAppException("Start time and end time are required when status is Working.");
            if (end <= start)
                throw new BadRequestAppException("End time must be after start time.");
        }
        else
        {
            if (start is not null || end is not null)
                throw new BadRequestAppException("Start and end times must be empty when status is Off.");
        }
    }

    /// <summary>
    /// Expands request into concrete dates. Past dates are excluded (caller validates none remain).
    /// </summary>
    private static IEnumerable<DateOnly> ExpandDates(BulkDoctorWorkScheduleRequestDto dto, DateOnly todayUtc)
    {
        switch (dto.Mode)
        {
            case ScheduleBulkMode.Daily:
                if (dto.SingleDate is null)
                    throw new BadRequestAppException("SingleDate is required for Daily mode.");
                yield return dto.SingleDate.Value;
                yield break;
            case ScheduleBulkMode.Weekly:
                if (dto.RangeStart is null)
                    throw new BadRequestAppException("RangeStart is required for Weekly mode (first day of a 7-day block).");
                var weekEnd = dto.RangeStart.Value.AddDays(6);
                for (var d = dto.RangeStart.Value; d <= weekEnd; d = d.AddDays(1))
                {
                    if (d >= todayUtc)
                        yield return d;
                }
                yield break;
            default:
                throw new BadRequestAppException("Invalid schedule mode.");
        }
    }

    private async Task<DoctorWorkScheduleDto> MapOneAsync(DoctorWorkSchedule s, CancellationToken cancellationToken)
    {
        var profile = await _users.GetAsync(s.Doctor.UserId, cancellationToken);
        return new DoctorWorkScheduleDto
        {
            Id = s.Id,
            DoctorId = s.DoctorId,
            DoctorFirstName = profile?.FirstName ?? string.Empty,
            DoctorLastName = profile?.LastName ?? string.Empty,
            ShiftDate = s.ShiftDate,
            StartTime = s.StartTime,
            EndTime = s.EndTime,
            Notes = s.Notes,
            Status = s.Status
        };
    }

    private async Task<IReadOnlyList<DoctorWorkScheduleDto>> MapListAsync(
        List<DoctorWorkSchedule> rows,
        CancellationToken cancellationToken)
    {
        var result = new List<DoctorWorkScheduleDto>();
        foreach (var s in rows)
            result.Add(await MapOneAsync(s, cancellationToken));
        return result;
    }
}
