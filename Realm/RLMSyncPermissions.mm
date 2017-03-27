////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMSyncPermissions_Private.hpp"

using namespace realm;
using ConditionType = Permission::Condition::Type;

namespace {

Permission::AccessLevel accessLevelForObjcAccessLevel(RLMSyncAccessLevel level) {
    switch (level) {
        case RLMSyncAccessLevelNone:
            return Permission::AccessLevel::None;
        case RLMSyncAccessLevelRead:
            return Permission::AccessLevel::Read;
        case RLMSyncAccessLevelWrite:
            return Permission::AccessLevel::Write;
        case RLMSyncAccessLevelAdmin:
            return Permission::AccessLevel::Admin;
    }
    REALM_UNREACHABLE();
}

RLMSyncAccessLevel objCAccessLevelForAccessLevel(Permission::AccessLevel level) {
    switch (level) {
        case Permission::AccessLevel::None:
            return RLMSyncAccessLevelNone;
        case Permission::AccessLevel::Read:
            return RLMSyncAccessLevelRead;
        case Permission::AccessLevel::Write:
            return RLMSyncAccessLevelWrite;
        case Permission::AccessLevel::Admin:
            return RLMSyncAccessLevelAdmin;
    }
    REALM_UNREACHABLE();
}

}

#pragma mark - Permission

@interface RLMSyncPermissionValue () {
@protected
    std::unique_ptr<Permission> _underlying;
    RLMSyncAccessLevel _accessLevel;
    NSString *_path;
}
@end

@implementation RLMSyncPermissionValue

// Private
- (instancetype)initWithAccessLevel:(RLMSyncAccessLevel)accessLevel
                               path:(NSString *)path {
    if (self = [super init]) {
        _accessLevel = accessLevel;
        _path = path;
    }
    return self;
}

- (instancetype)initWithRealmPath:(NSString *)path
                           userID:(NSString *)userID
                      accessLevel:(RLMSyncAccessLevel)accessLevel {
    return [[RLMSyncUserIDPermissionValue alloc] initWithRealmPath:path userID:userID accessLevel:accessLevel];
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

- (instancetype)initWithPermission:(const Permission&)permission {
    switch (permission.condition.type) {
        case ConditionType::UserId:
            self = [[RLMSyncUserIDPermissionValue alloc] initPrivate];
            break;
        case ConditionType::KeyValue:
            self = [[RLMSyncKeyValuePermissionValue alloc] initPrivate];
            break;
    }
    _underlying = std::make_unique<Permission>(permission);
    return self;
}

- (NSString *)path {
    if (auto permission = _underlying.get()) {
        return @(permission->path.c_str());
    }
    REALM_ASSERT(_path);
    return _path;
}

- (RLMSyncAccessLevel)accessLevel {
    if (auto permission = _underlying.get()) {
        return objCAccessLevelForAccessLevel(permission->access);
    }
    return _accessLevel;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[RLMSyncPermissionValue class]]) {
        RLMSyncPermissionValue *that = (RLMSyncPermissionValue *)object;
        return self.accessLevel == that.accessLevel && [self.path isEqual:that.path];
    }
    return NO;
}

- (realm::Permission)rawPermission {
    REALM_TERMINATE("Subclasses must override this method.");
}

@end

#pragma mark - User ID permission

@interface RLMSyncUserIDPermissionValue () {
    NSString *_userID;
}
@end

@implementation RLMSyncUserIDPermissionValue

- (instancetype)initPrivate {
    self = [super initPrivate];
    return self;
}

- (instancetype)initWithRealmPath:(NSString *)path
                           userID:(NSString *)userID
                      accessLevel:(RLMSyncAccessLevel)accessLevel {
    if (self = [super initWithAccessLevel:accessLevel path:path]) {
        _userID = userID;
    }
    return self;
}

- (NSString *)userID {
    if (auto permission = _underlying.get()) {
        REALM_ASSERT(permission->condition.type == ConditionType::UserId);
        return @(_underlying->condition.user_id.c_str());
    }
    return _userID;
}

- (realm::Permission)rawPermission {
    if (auto permission = _underlying.get()) {
        return *permission;
    }
    return Permission{
        [_path UTF8String],
        accessLevelForObjcAccessLevel(_accessLevel),
        Permission::Condition([_userID UTF8String])
    };
}

@end

#pragma mark - Key value permission

@implementation RLMSyncKeyValuePermissionValue

- (instancetype)initPrivate {
    self = [super initPrivate];
    return self;
}

- (NSString *)key {
    if (auto permission = _underlying.get()) {
        REALM_ASSERT(permission->condition.type == ConditionType::KeyValue);
        return @(std::get<0>(_underlying->condition.key_value).c_str());
    }
    REALM_TERMINATE("Not yet implemented for user-defined permissions");
}

- (NSString *)value {
    if (auto permission = _underlying.get()) {
        REALM_ASSERT(permission->condition.type == ConditionType::KeyValue);
        return @(std::get<1>(_underlying->condition.key_value).c_str());
    }
    REALM_TERMINATE("Not yet implemented for user-defined permissions");
}

- (realm::Permission)rawPermission {
    if (auto permission = _underlying.get()) {
        return *permission;
    }
    REALM_TERMINATE("Not yet implemented for user-defined permissions");
    // TODO: implement this
}

@end
