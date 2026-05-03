import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit, .passkey))
struct `Passkey View Params Tests` {

    // MARK: - PasskeyGuestRegistrationViewParams

    @Test
    func `PasskeyGuestRegistrationViewParams copyWith overrides individual fields`() {
        let original = Passage.Views.PasskeyGuestRegistrationViewParams(
            byEmail: false,
            byPhone: false,
            byUsername: false,
            error: nil,
            success: nil,
            signupBeginURL: nil,
            signupFinishURL: nil
        )

        let updated = original.copyWith(
            byEmail: true,
            byPhone: true,
            byUsername: true,
            error: "some error",
            success: "some success",
            signupBeginURL: "/begin",
            signupFinishURL: "/finish"
        )

        #expect(updated.byEmail == true)
        #expect(updated.byPhone == true)
        #expect(updated.byUsername == true)
        #expect(updated.error == "some error")
        #expect(updated.success == "some success")
        #expect(updated.signupBeginURL == "/begin")
        #expect(updated.signupFinishURL == "/finish")
    }

    @Test
    func `PasskeyGuestRegistrationViewParams copyWith preserves unspecified fields`() {
        let original = Passage.Views.PasskeyGuestRegistrationViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: true,
            error: "original error",
            success: "original success",
            signupBeginURL: "/auth/passkey/signup/begin",
            signupFinishURL: "/auth/passkey/signup/finish"
        )

        let updated = original.copyWith()

        #expect(updated.byEmail == true)
        #expect(updated.byPhone == false)
        #expect(updated.byUsername == true)
        #expect(updated.error == "original error")
        #expect(updated.success == "original success")
        #expect(updated.signupBeginURL == "/auth/passkey/signup/begin")
        #expect(updated.signupFinishURL == "/auth/passkey/signup/finish")
    }

    @Test
    func `PasskeyGuestRegistrationViewParams copyWith with only error set preserves other fields`() {
        let original = Passage.Views.PasskeyGuestRegistrationViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            error: nil,
            success: nil,
            signupBeginURL: "/begin",
            signupFinishURL: "/finish"
        )

        let updated = original.copyWith(error: "validation failed")

        #expect(updated.byEmail == true)
        #expect(updated.byPhone == false)
        #expect(updated.byUsername == false)
        #expect(updated.error == "validation failed")
        #expect(updated.success == nil)
        #expect(updated.signupBeginURL == "/begin")
        #expect(updated.signupFinishURL == "/finish")
    }

    @Test
    func `PasskeyGuestRegistrationViewParams copyWith with only success set preserves other fields`() {
        let original = Passage.Views.PasskeyGuestRegistrationViewParams(
            byEmail: false,
            byPhone: false,
            byUsername: true,
            error: nil,
            success: nil,
            signupBeginURL: "/begin",
            signupFinishURL: "/finish"
        )

        let updated = original.copyWith(success: "check your email")

        #expect(updated.byUsername == true)
        #expect(updated.success == "check your email")
        #expect(updated.error == nil)
        #expect(updated.signupBeginURL == "/begin")
    }

    // MARK: - PasskeyAuthenticationViewParams

    @Test
    func `PasskeyAuthenticationViewParams copyWith overrides all fields`() {
        let original = Passage.Views.PasskeyAuthenticationViewParams(
            error: nil,
            success: nil,
            authenticateBeginURL: nil,
            authenticateFinishURL: nil,
            redirectOnSuccess: nil
        )

        let updated = original.copyWith(
            error: "auth error",
            success: "auth success",
            authenticateBeginURL: "/begin",
            authenticateFinishURL: "/finish",
            redirectOnSuccess: "/home"
        )

        #expect(updated.error == "auth error")
        #expect(updated.success == "auth success")
        #expect(updated.authenticateBeginURL == "/begin")
        #expect(updated.authenticateFinishURL == "/finish")
        #expect(updated.redirectOnSuccess == "/home")
    }

    @Test
    func `PasskeyAuthenticationViewParams copyWith preserves unspecified fields`() {
        let original = Passage.Views.PasskeyAuthenticationViewParams(
            error: "existing error",
            success: nil,
            authenticateBeginURL: "/auth/passkey/authenticate/begin",
            authenticateFinishURL: "/auth/passkey/authenticate/finish",
            redirectOnSuccess: "/dashboard"
        )

        let updated = original.copyWith()

        #expect(updated.error == "existing error")
        #expect(updated.success == nil)
        #expect(updated.authenticateBeginURL == "/auth/passkey/authenticate/begin")
        #expect(updated.authenticateFinishURL == "/auth/passkey/authenticate/finish")
        #expect(updated.redirectOnSuccess == "/dashboard")
    }

    @Test
    func `PasskeyAuthenticationViewParams copyWith with only error set preserves other fields`() {
        let original = Passage.Views.PasskeyAuthenticationViewParams(
            error: nil,
            success: nil,
            authenticateBeginURL: "/begin",
            authenticateFinishURL: "/finish",
            redirectOnSuccess: "/home"
        )

        let updated = original.copyWith(error: "passkey not supported")

        #expect(updated.error == "passkey not supported")
        #expect(updated.success == nil)
        #expect(updated.authenticateBeginURL == "/begin")
        #expect(updated.authenticateFinishURL == "/finish")
        #expect(updated.redirectOnSuccess == "/home")
    }

    @Test
    func `PasskeyAuthenticationViewParams copyWith with redirectOnSuccess overrides correctly`() {
        let original = Passage.Views.PasskeyAuthenticationViewParams(
            error: nil,
            success: nil,
            authenticateBeginURL: "/begin",
            authenticateFinishURL: "/finish",
            redirectOnSuccess: "/old-path"
        )

        let updated = original.copyWith(redirectOnSuccess: "/new-path")

        #expect(updated.redirectOnSuccess == "/new-path")
        #expect(updated.authenticateBeginURL == "/begin")
        #expect(updated.authenticateFinishURL == "/finish")
    }
}
