namespace Doctors.Application.Common.Interfaces;

public interface ICurrentUserService
{
    string? UserId { get; }
    bool IsInRole(string role);
    int? GetDoctorId();
    Guid? GetPatientId();
    int? GetAssignedClinicId();
}
