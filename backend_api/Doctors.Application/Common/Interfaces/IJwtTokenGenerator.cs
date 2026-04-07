namespace Doctors.Application.Common.Interfaces;

public interface IJwtTokenGenerator
{
    string CreateToken(
        string userId,
        string email,
        IEnumerable<string> roles,
        int? doctorId,
        Guid? patientId,
        int? assignedClinicId);
}
