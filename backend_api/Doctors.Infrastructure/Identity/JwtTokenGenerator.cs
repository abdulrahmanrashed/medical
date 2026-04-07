using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.Configuration;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Doctors.Infrastructure.Identity;

public class JwtTokenGenerator : IJwtTokenGenerator
{
    private readonly JwtSettings _jwt;

    public JwtTokenGenerator(IOptions<JwtSettings> jwt)
    {
        _jwt = jwt.Value;
    }

    public string CreateToken(
        string userId,
        string email,
        IEnumerable<string> roles,
        int? doctorId,
        Guid? patientId,
        int? assignedClinicId)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId),
            new(JwtRegisteredClaimNames.Email, email),
            new(ClaimTypes.NameIdentifier, userId),
            new(ClaimTypes.Email, email)
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));
        if (doctorId is int d)
            claims.Add(new Claim(JwtClaimNames.DoctorId, d.ToString()));
        if (patientId is Guid p)
            claims.Add(new Claim(JwtClaimNames.PatientId, p.ToString()));
        if (assignedClinicId is int c)
            claims.Add(new Claim(JwtClaimNames.AssignedClinicId, c.ToString()));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddMinutes(_jwt.ExpiryMinutes);
        var token = new JwtSecurityToken(
            issuer: _jwt.Issuer,
            audience: _jwt.Audience,
            claims: claims,
            expires: expires,
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
