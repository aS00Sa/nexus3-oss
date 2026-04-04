import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import groovy.transform.Field
import org.sonatype.nexus.security.role.RoleIdentifier
import org.sonatype.nexus.security.user.InvalidCredentialsException
import org.sonatype.nexus.security.user.UserManager
import org.sonatype.nexus.security.user.UserNotFoundException
import org.sonatype.nexus.security.user.User

List<Map<String, String>> actionDetails = []
@Field Map scriptResults = [changed: false, error: false]
scriptResults.put('action_details', actionDetails)
authManager = security.securitySystem.getAuthorizationManager(UserManager.DEFAULT_SOURCE)

def updateUser(userDef, currentResult, boolean doApplyPassword) {
    User user = security.securitySystem.getUser(userDef.username)

    user.setFirstName(userDef.first_name)
    user.setLastName(userDef.last_name)
    user.setEmailAddress(userDef.email)

    if (user != security.securitySystem.getUser(userDef.username)) {
        security.securitySystem.updateUser(user)
        currentResult.put('status', 'updated')
        scriptResults['changed'] = true
    }

    Set<RoleIdentifier> existingRoles = user.getRoles()
    Set<RoleIdentifier> definedRoles = []
    userDef.roles.each { roleDef ->
        RoleIdentifier role = new RoleIdentifier("default", authManager.getRole(roleDef).roleId);
        definedRoles.add(role)
    }
    if (! existingRoles.equals(definedRoles)) {
        security.securitySystem.setUsersRoles(user.getUserId(), "default", definedRoles)
        currentResult.put('status', 'updated')
        scriptResults['changed'] = true
    }

    if (doApplyPassword) {
        try {
            security.securitySystem.changePassword(userDef.username, userDef.password, userDef.password)
        } catch (InvalidCredentialsException ignored) {
            security.securitySystem.changePassword(userDef.username, userDef.password)
            currentResult.put('status', 'updated')
            scriptResults['changed'] = true
        }
    }
    log.info("Updated user {}", userDef.username)
}

def addUser(userDef, currentResult) {
    try {
        security.addUser(userDef.username, userDef.first_name, userDef.last_name, userDef.email, true, userDef.password, userDef.roles)
        currentResult.put('status', 'updated')
        scriptResults['changed'] = true
        log.info("Created user {}", userDef.username)
    } catch (Exception e) {
        currentResult.put('status', 'error')
        currentResult.put('error_msg', e.toString())
        scriptResults['error'] = true
    }
}

def deleteUser(userDef, currentResult) {
    try {
        security.securitySystem.deleteUser(userDef.username, UserManager.DEFAULT_SOURCE)
        log.info("Deleted user {}", userDef.username)
        currentResult.put('status', 'deleted')
        scriptResults['changed'] = true
    } catch (UserNotFoundException ignored) {
        log.info("Delete user: user {} does not exist", userDef.username)
    } catch (Exception e) {
        currentResult.put('status', 'error')
        currentResult.put('error_msg', e.toString())
        scriptResults['error'] = true
    }
}

/* Main */

def parsed_root = new JsonSlurper().parseText(args)
boolean applyPasswords = false
List userList = []

if (parsed_root instanceof Map) {
    def ap = parsed_root.get('apply_passwords')
    applyPasswords = (ap instanceof Boolean) ? (Boolean) ap : Boolean.parseBoolean(String.valueOf(ap ?: 'false'))
    def u = parsed_root.get('users')
    userList = (u instanceof List) ? (List) u : []
} else if (parsed_root instanceof List) {
    // Legacy JSON body: list of users only (previous behaviour — always apply passwords)
    userList = (List) parsed_root
    applyPasswords = true
} else {
    userList = []
}

userList.each { userDef ->

    state = userDef.get('state', 'present')

    Map<String, String> currentResult = [username: userDef.username, state: state]
    currentResult.put('status', 'no change')

    if (state == 'absent') {
        deleteUser(userDef, currentResult)
    } else {
        try {
            updateUser(userDef, currentResult, applyPasswords)
        } catch (UserNotFoundException ignored) {
            addUser(userDef, currentResult)
        } catch (Exception e) {
            currentResult.put('status', 'error')
            currentResult.put('error_msg', e.toString())
            scriptResults['error'] = true
        }
    }

    scriptResults['action_details'].add(currentResult)
}

return JsonOutput.toJson(scriptResults)
