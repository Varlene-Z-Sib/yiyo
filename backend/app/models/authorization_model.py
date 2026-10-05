from enum import StrEnum

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)


class AppRole(StrEnum):
    USER = "user"
    MODERATOR = "moderator"
    SUPER_ADMIN = "super_admin"


class MembershipRole(StrEnum):
    PROMOTER = "promoter"
    VENUE_MANAGER = "venue_manager"


class MembershipStatus(StrEnum):
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    REJECTED = "rejected"


class BusinessMembership(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    id: str

    user_id: str

    role: MembershipRole

    # Promoters are global organiser identities.
    # Venue managers are attached to one specific venue.
    venue_id: str | None = None

    status: MembershipStatus = (
        MembershipStatus.ACTIVE
    )

    created_at: str | None = None
    created_at_unix: int | None = None

    updated_at: str | None = None
    updated_at_unix: int | None = None

    @model_validator(
        mode="after"
    )
    def validate_membership(
        self,
    ):
        if (
            self.role
            == MembershipRole.VENUE_MANAGER
            and not (
                self.venue_id
                or ""
            ).strip()
        ):
            raise ValueError(
                "Venue managers require "
                "a venue_id"
            )

        if (
            self.role
            == MembershipRole.PROMOTER
            and self.venue_id is not None
        ):
            raise ValueError(
                "Promoter memberships "
                "must not include venue_id"
            )

        return self


class MembershipGrantRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    user_id: str = Field(
        min_length=1,
        max_length=256,
    )

    role: MembershipRole

    venue_id: str | None = Field(
        default=None,
        max_length=256,
    )

    @model_validator(
        mode="after"
    )
    def validate_grant(
        self,
    ):
        if (
            self.role
            == MembershipRole.VENUE_MANAGER
            and not (
                self.venue_id
                or ""
            ).strip()
        ):
            raise ValueError(
                "venue_id is required "
                "for venue_manager"
            )

        if (
            self.role
            == MembershipRole.PROMOTER
            and self.venue_id is not None
        ):
            raise ValueError(
                "promoter must not "
                "include venue_id"
            )

        return self


class AuthorizationContext(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
    )

    uid: str

    app_role: AppRole = (
        AppRole.USER
    )

    @property
    def is_moderator(
        self,
    ) -> bool:
        return self.app_role in {
            AppRole.MODERATOR,
            AppRole.SUPER_ADMIN,
        }

    @property
    def is_super_admin(
        self,
    ) -> bool:
        return (
            self.app_role
            == AppRole.SUPER_ADMIN
        )


class EffectivePermissions(BaseModel):
    uid: str

    app_role: AppRole

    is_promoter: bool = False

    managed_venue_ids: list[str] = (
        Field(
            default_factory=list
        )
    )

    moderate_content: bool = False
    super_admin: bool = False

    create_events: bool = False
    manage_venues: bool = False